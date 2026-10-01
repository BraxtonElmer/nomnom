import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../ai/client.dart';
import '../../data/keys.dart';
import '../../data/models.dart';
import '../../data/store.dart';
import '../../theme/tokens.dart';
import '../../ui/buttons.dart';
import '../../ui/controls.dart';
import 'about_form.dart';

enum _Check { idle, checking, ok, failed }

/// Provider, key, endpoint and model. Saves to the store once a check passes.
class AiForm extends StatefulWidget {
  const AiForm({super.key, this.onConnected});

  final VoidCallback? onConnected;

  @override
  State<AiForm> createState() => _AiFormState();
}

class _AiFormState extends State<AiForm> {
  late Provider _provider = Store.i.ai.provider;
  late String _model = Store.i.ai.model;
  final _key = TextEditingController();
  late final _base = TextEditingController(text: Store.i.ai.baseUrl);
  final _manualModel = TextEditingController();
  _Check _check = _Check.idle;
  String _message = '';
  List<String> _models = [];
  bool _showKey = false;

  @override
  void initState() {
    super.initState();
    _loadKey();
    if (Store.i.ai.ready) {
      _check = _Check.ok;
      _message = 'Connected · ${Store.i.ai.model}';
    }
  }

  Future<void> _loadKey() async {
    final k = await KeyVault.read(_provider);
    if (mounted) setState(() => _key.text = k);
  }

  @override
  void dispose() {
    _key.dispose();
    _base.dispose();
    _manualModel.dispose();
    super.dispose();
  }

  void _switch(Provider p) {
    if (p == _provider) return;
    setState(() {
      _provider = p;
      _check = _Check.idle;
      _message = '';
      _models = [];
      _model = '';
    });
    _loadKey();
  }

  AiConfig get _config => AiConfig(provider: _provider, model: _model, baseUrl: _base.text.trim());

  Future<void> _verify() async {
    FocusScope.of(context).unfocus();
    final key = _key.text.trim();
    if (_provider != Provider.custom && key.isEmpty) {
      setState(() {
        _check = _Check.failed;
        _message = 'Paste your API key first.';
      });
      return;
    }
    if (_provider == Provider.custom && _base.text.trim().isEmpty) {
      setState(() {
        _check = _Check.failed;
        _message = 'Add the endpoint URL first.';
      });
      return;
    }
    setState(() => _check = _Check.checking);
    try {
      final models = await AiClient.of(_config, key).models();
      if (models.isEmpty && _provider != Provider.custom) {
        throw const AiException('That key works but has no chat models available.');
      }
      final keep = models.contains(_model) ? _model : pickModel(_provider, models);
      _manualModel.text = keep;
      await _save(key, keep);
      setState(() {
        _models = models;
        _check = _Check.ok;
        _message = models.isEmpty
            ? 'Endpoint reachable. Type a model name below.'
            : 'Key works · ${models.length} models available';
      });
    } on AiException catch (e) {
      setState(() {
        _check = _Check.failed;
        _message = e.message;
      });
    }
  }

  Future<void> _save(String key, String model) async {
    _model = model;
    await KeyVault.write(_provider, key);
    await Store.i.saveAi(_config);
    if (model.isNotEmpty) widget.onConnected?.call();
  }

  Future<void> _pickModel() async {
    final m = await showPaperSheet<String>(
      context,
      (context) => SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.6,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          children: [
            const Text('Model', style: T.heading),
            const SizedBox(height: 4),
            Text(
              'Bigger models read meals more accurately; smaller ones reply faster.',
              style: T.small,
            ),
            const SizedBox(height: 8),
            for (final (i, id) in _models.indexed)
              RadioRow(
                title: id,
                selected: id == _model,
                last: i == _models.length - 1,
                onTap: () => Navigator.pop(context, id),
              ),
          ],
        ),
      ),
    );
    if (m != null) {
      await _save(_key.text.trim(), m);
      setState(() => _message = 'Connected · $m');
    }
  }

  @override
  Widget build(BuildContext context) {
    final link = switch (_provider) {
      Provider.groq => ('Get a free Groq key', 'https://console.groq.com/keys'),
      Provider.gemini => ('Get a free Gemini key', 'https://aistudio.google.com/apikey'),
      Provider.custom => ('About Ollama', 'https://ollama.com'),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (i, p) in Provider.values.indexed)
          RadioRow(
            title: p.label,
            trailing: p.blurb,
            selected: p == _provider,
            last: i == Provider.values.length - 1,
            onTap: () => _switch(p),
          ),
        const SizedBox(height: 20),
        if (_provider == Provider.gemini) ...[
          Text(
            'Gemini’s free tier can be as low as 20 requests a day per model, and each log '
            'uses one or two. Fine for trying out; Groq lasts much longer for daily use.',
            style: T.small,
          ),
          const SizedBox(height: 20),
        ],
        if (_provider == Provider.custom) ...[
          PaperField(
            label: 'Endpoint',
            controller: _base,
            hint: 'http://192.168.1.20:11434/v1',
            keyboard: TextInputType.url,
            onChanged: (_) => setState(() => _check = _Check.idle),
          ),
          const SizedBox(height: 8),
          Text(
            'Any OpenAI-compatible server. For Ollama on your computer, start it with '
            'OLLAMA_HOST=0.0.0.0 and use your computer’s Wi-Fi address.',
            style: T.small,
          ),
          const SizedBox(height: 20),
        ],
        Stack(
          alignment: Alignment.centerRight,
          children: [
            PaperField(
              label: _provider == Provider.custom ? 'API key (optional)' : 'API key',
              controller: _key,
              obscure: !_showKey,
              hint: _provider == Provider.gemini
                  ? 'AIza…'
                  : (_provider == Provider.groq ? 'gsk_…' : ''),
              onChanged: (_) => setState(() => _check = _Check.idle),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 14),
              child: IconButton(
                tooltip: _showKey ? 'Hide key' : 'Show key',
                onPressed: () => setState(() => _showKey = !_showKey),
                icon: Icon(
                  _showKey ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  color: C.ink2,
                  size: 20,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: AnimatedSwitcher(
                duration: Motion.fast,
                layoutBuilder: (current, previous) =>
                    Stack(alignment: Alignment.centerLeft, children: [...previous, ?current]),
                child: switch (_check) {
                  _Check.checking => const Align(
                    key: ValueKey('c'),
                    alignment: Alignment.centerLeft,
                    child: Dots(size: 5),
                  ),
                  _Check.ok => Row(
                    key: const ValueKey('ok'),
                    children: [
                      const Icon(Icons.check_rounded, size: 16, color: C.good),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(_message, style: T.small.copyWith(color: C.good)),
                      ),
                    ],
                  ),
                  _Check.failed => Text(
                    _message,
                    key: const ValueKey('f'),
                    style: T.small.copyWith(color: C.tomato),
                  ),
                  _Check.idle => Text(
                    'Stored only on this phone.',
                    key: const ValueKey('i'),
                    style: T.small,
                  ),
                },
              ),
            ),
            TextLink(label: link.$1, onTap: () => launchUrl(Uri.parse(link.$2))),
          ],
        ),
        const SizedBox(height: 16),
        if (_check == _Check.ok && _models.isNotEmpty)
          RuledRow(label: 'Model', value: _model, onTap: _pickModel, last: true),
        if (_check == _Check.ok && _models.isEmpty && _provider == Provider.custom)
          PaperField(
            label: 'Model name',
            controller: _manualModel,
            hint: 'llama3.1:8b',
            onChanged: (v) => _save(_key.text.trim(), v.trim()),
          ),
        if (_check != _Check.ok)
          OutlineButton(
            label: _check == _Check.checking ? 'Checking…' : 'Check connection',
            onTap: _check == _Check.checking ? null : _verify,
          ),
      ],
    );
  }
}

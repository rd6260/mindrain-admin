import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mindrain_admin/features/send_emails/bloc/send_emails_bloc.dart';
import 'package:flutter/rendering.dart';

const _accent = Color(0xFF6366F1);
const _teal = Color(0xFF06B6D4);

class ComposerSection extends StatefulWidget {
  const ComposerSection({
    super.key,
    required this.subjectCtrl,
    required this.bodyCtrl,
    required this.htmlBodyCtrl,
    required this.onPreview,
    required this.onSuggestionInserted,
    this.onRegisterInsertFn,
  });

  final TextEditingController subjectCtrl;
  final TextEditingController bodyCtrl;
  final TextEditingController htmlBodyCtrl;
  final VoidCallback onPreview;
  final void Function(String newText, int newCursor) onSuggestionInserted;
  /// Called once in initState with a reference to [insertColumn].
  final void Function(void Function(String))? onRegisterInsertFn;

  @override
  State<ComposerSection> createState() => _ComposerSectionState();
}

class _ComposerSectionState extends State<ComposerSection> {
  // ── Focus Nodes ───────────────────────────────────────────────────────────
  final _bodyFocusNode = FocusNode();
  final _htmlFocusNode = FocusNode();
  
  // ── Autocomplete Overlay ──────────────────────────────────────────────────
  final _bodyLayerLink = LayerLink();
  final _targetKey = GlobalKey();
  OverlayEntry? _overlayEntry;

  Offset _getCursorOffset() {
    final isHtml = context.read<SendEmailsBloc>().state.isHtmlMode;
    final ctrl = isHtml ? widget.htmlBodyCtrl : widget.bodyCtrl;
    final focusNode = isHtml ? _htmlFocusNode : _bodyFocusNode;
    
    final renderObject = focusNode.context?.findRenderObject();
    if (renderObject == null) return const Offset(0, 262);
    
    RenderEditable? renderEditable;
    void visitor(RenderObject child) {
      if (child is RenderEditable) {
        renderEditable = child;
      } else if (renderEditable == null) {
        child.visitChildren(visitor);
      }
    }
    if (renderObject is RenderEditable) {
      renderEditable = renderObject;
    } else {
      renderObject.visitChildren(visitor);
    }
    
    if (renderEditable == null) return const Offset(0, 262);
    
    try {
      final cursorRect = renderEditable!.getLocalRectForCaret(ctrl.selection.base);
      final targetRO = _targetKey.currentContext?.findRenderObject();
      if (targetRO == null) return const Offset(0, 262);
      
      final transform = renderEditable!.getTransformTo(targetRO);
      final p = MatrixUtils.transformPoint(transform, cursorRect.bottomLeft);
      
      return Offset(p.dx, p.dy + 4);
    } catch (e) {
      return const Offset(0, 262);
    }
  }

  @override
  void initState() {
    super.initState();
    widget.onRegisterInsertFn?.call(insertColumn);
    widget.bodyCtrl.addListener(_onBodyControllerChanged);
    widget.htmlBodyCtrl.addListener(_onHtmlBodyControllerChanged);
    
    _bodyFocusNode.addListener(() {
      if (!_bodyFocusNode.hasFocus) _hideOverlay();
    });
    _htmlFocusNode.addListener(() {
      if (!_htmlFocusNode.hasFocus) _hideOverlay();
    });
  }

  @override
  void dispose() {
    widget.bodyCtrl.removeListener(_onBodyControllerChanged);
    widget.htmlBodyCtrl.removeListener(_onHtmlBodyControllerChanged);
    _bodyFocusNode.dispose();
    _htmlFocusNode.dispose();
    _hideOverlay();
    super.dispose();
  }

  void _onBodyControllerChanged() {
    context.read<SendEmailsBloc>().add(
          BodyTextChanged(
            text: widget.bodyCtrl.text,
            cursorOffset: widget.bodyCtrl.selection.baseOffset,
          ),
        );
  }

  void _onHtmlBodyControllerChanged() {
    context.read<SendEmailsBloc>().add(
          HtmlBodyChanged(
            text: widget.htmlBodyCtrl.text,
            cursorOffset: widget.htmlBodyCtrl.selection.baseOffset,
          ),
        );
  }

  // ── Overlay Controls ───────────────────────────────────────────────────────

  void _showOverlay() {
    if (_overlayEntry != null) {
      _overlayEntry!.markNeedsBuild();
      return;
    }
    final bloc = context.read<SendEmailsBloc>();
    _overlayEntry = OverlayEntry(
      builder: (context) {
        final offset = _getCursorOffset();
        return Positioned(
          width: 280,
          child: CompositedTransformFollower(
            link: _bodyLayerLink,
            showWhenUnlinked: false,
            offset: offset,
            child: Material(
              elevation: 8,
              borderRadius: BorderRadius.circular(10),
              color: Colors.white,
              child: BlocBuilder<SendEmailsBloc, SendEmailsState>(
                bloc: bloc,
                buildWhen: (p, c) =>
                    p.suggestions != c.suggestions ||
                    p.selectedSuggestionIndex != c.selectedSuggestionIndex,
                builder: (ctx, state) => _AutocompleteMenu(
                  suggestions: state.suggestions,
                  selectedIndex: state.selectedSuggestionIndex,
                  onSelect: _insertSuggestion,
                ),
              ),
            ),
          ),
        );
      },
    );
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _hideOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _insertSuggestion(String column) {
    final isHtml = context.read<SendEmailsBloc>().state.isHtmlMode;
    final ctrl = isHtml ? widget.htmlBodyCtrl : widget.bodyCtrl;
    final text = ctrl.text;
    final cursor = ctrl.selection.baseOffset;
    if (cursor < 0) return;

    final before = text.substring(0, cursor);
    final openIdx = before.lastIndexOf('{{');
    if (openIdx == -1) return;

    final newText =
        '${text.substring(0, openIdx)}{{$column}}${text.substring(cursor)}';
    final newCursor = openIdx + '{{$column}}'.length;

    ctrl.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newCursor),
    );

    context.read<SendEmailsBloc>().add(const OverlayDismissed());
    _hideOverlay();
    
    if (isHtml) {
      _htmlFocusNode.requestFocus();
    } else {
      _bodyFocusNode.requestFocus();
    }
    widget.onSuggestionInserted(newText, newCursor);
  }

  /// Called by [ColumnInsertScope] when a column chip is tapped.
  void insertColumn(String column) {
    _hideOverlay();
    final isHtml = context.read<SendEmailsBloc>().state.isHtmlMode;
    final ctrl = isHtml ? widget.htmlBodyCtrl : widget.bodyCtrl;
    final text = ctrl.text;
    final cursor = ctrl.selection.baseOffset.clamp(0, text.length);
    final before = text.substring(0, cursor);
    final after = text.substring(cursor);
    final replacement = before.endsWith('{{') ? '$column}}' : '{{$column}}';
    final newText = '$before$replacement$after';
    final newCursor = before.length + replacement.length;

    ctrl.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newCursor),
    );
    context.read<SendEmailsBloc>().add(const OverlayDismissed());
    
    if (isHtml) {
      _htmlFocusNode.requestFocus();
    } else {
      _bodyFocusNode.requestFocus();
    }
  }

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      context.read<SendEmailsBloc>().add(const OverlayDismissed());
      _hideOverlay();
      return KeyEventResult.handled;
    }
    if (_overlayEntry != null) {
      if (event.logicalKey == LogicalKeyboardKey.tab) {
        context.read<SendEmailsBloc>().add(const NextSuggestionRequested());
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.enter) {
        final s = context.read<SendEmailsBloc>().state;
        if (s.suggestions.isNotEmpty) {
          _insertSuggestion(s.suggestions[s.selectedSuggestionIndex]);
        }
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<SendEmailsBloc, SendEmailsState>(
      listenWhen: (p, c) =>
          p.suggestions != c.suggestions ||
          p.selectedSuggestionIndex != c.selectedSuggestionIndex,
      listener: (context, state) {
        if (state.suggestions.isEmpty) {
          _hideOverlay();
        } else {
          _showOverlay();
          _overlayEntry?.markNeedsBuild();
        }
      },
      child: BlocBuilder<SendEmailsBloc, SendEmailsState>(
        buildWhen: (p, c) =>
            p.detectedVars != c.detectedVars ||
            p.testHeaders != c.testHeaders ||
            p.finalHeaders != c.finalHeaders ||
            p.isRunning != c.isRunning ||
            p.isHtmlMode != c.isHtmlMode ||
            p.testRows != c.testRows,
        builder: (context, state) {
          final allHeaders = {...state.testHeaders, ...state.finalHeaders};
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Subject
              TextField(
                controller: widget.subjectCtrl,
                enabled: !state.isRunning,
                decoration: const InputDecoration(
                  labelText: 'Subject',
                  border: OutlineInputBorder(),
                  isDense: true,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
              const SizedBox(height: 14),

              // Mode toggle button (SegmentedButton)
              Row(
                children: [
                  const Text(
                    'Email Format:',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment<bool>(
                        value: false,
                        icon: Icon(Icons.text_fields_rounded, size: 14),
                        label: Text('Plain Text'),
                      ),
                      ButtonSegment<bool>(
                        value: true,
                        icon: Icon(Icons.code_rounded, size: 14),
                        label: Text('HTML'),
                      ),
                    ],
                    selected: {state.isHtmlMode},
                    onSelectionChanged: (val) {
                      if (val.isNotEmpty) {
                        context.read<SendEmailsBloc>().add(
                              EmailModeChanged(isHtml: val.first),
                            );
                      }
                    },
                    style: SegmentedButton.styleFrom(
                      selectedBackgroundColor: _accent.withValues(alpha: 0.1),
                      selectedForegroundColor: _accent,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Editor Container (Plain Text or HTML wrapped in Target link)
              SizedBox(
                height: 260,
                child: CompositedTransformTarget(
                  key: _targetKey,
                  link: _bodyLayerLink,
                  child: state.isHtmlMode
                      ? Focus(
                          onKeyEvent: (node, event) => _onKeyEvent(node, event),
                          child: TextField(
                            controller: widget.htmlBodyCtrl,
                            focusNode: _htmlFocusNode,
                            enabled: !state.isRunning,
                            maxLines: null,
                            expands: true,
                            textAlignVertical: TextAlignVertical.top,
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 13,
                              height: 1.55,
                            ),
                            decoration: InputDecoration(
                              labelText:
                                  'HTML body  —  {{column_name}} variables work here too',
                              alignLabelWithHint: true,
                              border: OutlineInputBorder(
                                borderSide: BorderSide(
                                    color: _teal.withValues(alpha: 0.5)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderSide: BorderSide(color: _teal, width: 1.5),
                              ),
                              contentPadding: const EdgeInsets.all(14),
                              hintText:
                                  '<p>Dear <strong>{{name}}</strong>,</p>\n<p>Your registration is confirmed.</p>',
                              hintStyle: TextStyle(
                                color: Colors.black.withValues(alpha: 0.25),
                                fontFamily: 'monospace',
                                fontSize: 13,
                              ),
                            ),
                          ),
                        )
                      : Focus(
                          onKeyEvent: (node, event) => _onKeyEvent(node, event),
                          child: TextField(
                            controller: widget.bodyCtrl,
                            focusNode: _bodyFocusNode,
                            enabled: !state.isRunning,
                            maxLines: null,
                            expands: true,
                            textAlignVertical: TextAlignVertical.top,
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 13,
                              height: 1.55,
                            ),
                            decoration: InputDecoration(
                              labelText:
                                  'Plain text  —  use {{column_name}} for variables',
                              alignLabelWithHint: true,
                              border: const OutlineInputBorder(),
                              contentPadding: const EdgeInsets.all(14),
                              hintText:
                                  'Dear {{name}},\n\nYour registration is confirmed.\n...',
                              hintStyle: TextStyle(
                                color: Colors.black.withValues(alpha: 0.25),
                                fontFamily: 'monospace',
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                ),
              ),

              // Variable chips
              if (state.detectedVars.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      'Variables:',
                      style: TextStyle(
                          fontSize: 12,
                          color: Colors.black.withValues(alpha: 0.5)),
                    ),
                    ...state.detectedVars.map((v) {
                      final exists = allHeaders.contains(v);
                      return Chip(
                        label: Text(
                          '{{$v}}',
                          style: TextStyle(
                            fontSize: 11,
                            color: exists
                                ? Colors.green.shade800
                                : Colors.red.shade700,
                          ),
                        ),
                        backgroundColor:
                            exists ? Colors.green.shade50 : Colors.red.shade50,
                        side: BorderSide(
                          color: exists
                              ? Colors.green.shade200
                              : Colors.red.shade200,
                        ),
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      );
                    }),
                  ],
                ),
              ],

              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton.icon(
                    onPressed:
                        state.testRows.isEmpty ? null : widget.onPreview,
                    icon: const Icon(Icons.preview_rounded, size: 16),
                    label: const Text('Preview with test data'),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

// ── Autocomplete menu ─────────────────────────────────────────────────────────

class _AutocompleteMenu extends StatelessWidget {
  const _AutocompleteMenu({
    required this.suggestions,
    required this.selectedIndex,
    required this.onSelect,
  });

  final List<String> suggestions;
  final int selectedIndex;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            color: const Color(0xFFF4F5F7),
            child: Row(
              children: [
                const Icon(Icons.data_array_rounded,
                    size: 12, color: _accent),
                const SizedBox(width: 6),
                Text(
                  'Available columns',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.black.withValues(alpha: 0.45),
                    letterSpacing: 0.3,
                  ),
                ),
                const Spacer(),
                Text(
                  '↹ to cycle · ↵ to insert',
                  style: TextStyle(
                    fontSize: 9,
                    color: Colors.black.withValues(alpha: 0.3),
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1, color: Color(0xFFE4E4EF)),
          ...suggestions.asMap().entries.map(
                (e) => _AutocompleteItem(
                  column: e.value,
                  isSelected: e.key == selectedIndex,
                  onPointerDown: () => onSelect(e.value),
                ),
              ),
        ],
      ),
    );
  }
}

class _AutocompleteItem extends StatefulWidget {
  const _AutocompleteItem({
    required this.column,
    required this.isSelected,
    required this.onPointerDown,
  });
  final String column;
  final bool isSelected;
  final VoidCallback onPointerDown;

  @override
  State<_AutocompleteItem> createState() => _AutocompleteItemState();
}

class _AutocompleteItemState extends State<_AutocompleteItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final highlighted = widget.isSelected || _hovered;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Listener(
        onPointerDown: (_) => widget.onPointerDown(),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 80),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: widget.isSelected
                ? _accent.withValues(alpha: 0.10)
                : _hovered
                    ? _accent.withValues(alpha: 0.05)
                    : Colors.white,
            border: widget.isSelected
                ? const Border(left: BorderSide(color: _accent, width: 3))
                : const Border(
                    left: BorderSide(color: Colors.transparent, width: 3)),
          ),
          child: Row(
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: highlighted
                      ? _accent.withValues(alpha: 0.15)
                      : _accent.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Center(
                  child: Text(
                    '{ }',
                    style: TextStyle(
                      fontSize: 8,
                      fontFamily: 'monospace',
                      color: _accent,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                widget.column,
                style: TextStyle(
                  fontSize: 13,
                  fontFamily: 'monospace',
                  color:
                      widget.isSelected ? _accent : const Color(0xFF1A1A2E),
                  fontWeight: widget.isSelected
                      ? FontWeight.w600
                      : FontWeight.w500,
                ),
              ),
              const Spacer(),
              AnimatedOpacity(
                opacity: highlighted ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 80),
                child: Text(
                  '{{${widget.column}}}',
                  style: TextStyle(
                    fontSize: 10,
                    fontFamily: 'monospace',
                    color: _accent.withValues(alpha: 0.55),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

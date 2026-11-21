import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:window_manager/window_manager.dart';

/// Used only by the UI builder for now
enum _WindowControlButtonType {
  MINIMIZE,
  MAXIMIZE,
  MAXIMIZE_RESTORE,
  CLOSE
}

/// Utility widget for building custom window control buttons
class _WindowControlButton extends StatefulWidget {
  final _WindowControlButtonType buttonType;
  final VoidCallback? onPressed;

  const _WindowControlButton({ required this.buttonType, required this.onPressed });

  @override
  State<_WindowControlButton> createState() => _WindowControlButtonState();
}

/// State of [_WindowControlButton]
class _WindowControlButtonState extends State<_WindowControlButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    late final Widget btnWidget; // build btnWidget

    late Color bg, fg;
    if (!_hovered) {
      bg = Colors.transparent;
      fg = theme.colorScheme.onSurface;
    } else {
      bg = widget.buttonType == _WindowControlButtonType.CLOSE
        ? theme.colorScheme.error
        :  theme.colorScheme.surfaceTint;
      fg = theme.colorScheme.surface;
    }


    switch (widget.buttonType) { 
      case _WindowControlButtonType.MINIMIZE:
        btnWidget = Container(
          width: 22,
          height: 2.5,
          color: fg,
        );
        break;
      case _WindowControlButtonType.MAXIMIZE:
        btnWidget = Container(
          width: 17,
          height: 17,
          decoration: BoxDecoration(
            border: Border.all(color: fg, width: 2.5)
          )
        );
        break;
      case _WindowControlButtonType.MAXIMIZE_RESTORE:
       btnWidget = CustomPaint(
          size: const Size(19, 19),
          painter: _RestoreGlyphPainter(
            color: fg,
            strokeWidth: 2.5,
          ),
        );
        break;
      case _WindowControlButtonType.CLOSE:
        btnWidget = Icon(Icons.close, size: 26, color: fg);
        break;
    }

    // integrate btnWidget, bg color into MouseRegion
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() {
        _hovered = true;
      }),
      onExit: (_) => setState(() {
        _hovered = false;
      }),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onPressed,
        child: Container(
          width: 42,
          height: 42,
          color: bg,
          alignment: Alignment.center,
          child: btnWidget,
        ),
      ),
    );
  }
}

/// Paints the "restore down" glyph (two overlapping squares) shown when the window is maximized
class _RestoreGlyphPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;

  const _RestoreGlyphPainter({ required this.color, required this.strokeWidth });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeJoin = StrokeJoin.round;

    final double inset = strokeWidth / 2;
    final double offset = 3.5; // how far the two squares are shifted
    final double sq = size.width - offset - inset; // side length of each square
    const double r = 2.5; // corner radius

    // Front square (bottom-left)
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(inset, offset, sq - inset, sq),
        const Radius.circular(r),
      ),
      paint,
    );

    // Back square (top-right): only the visible L-shaped part
    // 
    // // this would render a sharp corner: 
    // final back = Path()
    // ..moveTo(offset, 0)
    // ..lineTo(size.width - inset, 0)
    // ..lineTo(size.width - inset, size.height - offset)
    //
    // // this renders everything except the arc between
    // final back = Path()
    // ..moveTo(offset, 0)
    // ..lineTo(size.width - inset - r, 0)
    // // ADD ARC HERE
    // ..moveTo(size.width - inset, r)
    // ..lineTo(size.width - inset, size.height - offset)

    final back = Path()
    ..moveTo(offset, 0)
    ..lineTo(size.width - inset - r, 0)
    ..arcToPoint(
      Offset(size.width - inset, r),
      radius: const Radius.circular(r)
    )
    ..lineTo(size.width - inset, size.height - offset);

    canvas.drawPath(back, paint);
  }

  @override
  bool shouldRepaint(_RestoreGlyphPainter old) => old.color != color || old.strokeWidth != strokeWidth;
}

/// Wrapper over window manager so that users can provide a custom title bar widget
/// to be shown aligned to the left of the title bar. This class will handle the close buttons
/// Intended to be used only on windows platforms with the window_manager
class CustomTitleBarWindowsApp extends StatefulWidget {
  final String windowTitle;

  final WidgetBuilder titleBarWidgetBuilder;
  final WidgetBuilder appContentWidgetBuilder;

  final ValueNotifier<ThemeMode> themeModeNotifier;
  final ValueNotifier<Locale> localeNotifier;
  final ThemeData darkTheme;
  final ThemeData lightTheme;

  /// If true, asks the user for confirmation before the window closes
  final bool confirmOnClose;
  /// This will run exactly once, after the user confirms exit. 
  /// A 5 second loading bar will be shown to let this method execute
  final Future Function()? shutdownAction;

  /// Will place [titleBarWidgetBuilder] in a [Material] widget to make it has a Material root in the tree
  /// For [appContentWidgetBuilder], you must provide a valid [Material] root somewhere in the tree. Eg: Provide a scaffold
  const CustomTitleBarWindowsApp({
    super.key, 
    required this.windowTitle,
    required this.titleBarWidgetBuilder, 
    required this.appContentWidgetBuilder,
    required this.themeModeNotifier,
    required this.localeNotifier,
    required this.darkTheme,
    required this.lightTheme,
    this.confirmOnClose = false,
    this.shutdownAction = null,
  });

  @override
  State<StatefulWidget> createState() => _CustomTitleBarWindowsAppState();
}

/// State of [CustomTitleBarWindowsApp]
class _CustomTitleBarWindowsAppState extends State<CustomTitleBarWindowsApp> with WindowListener {
  static final Logger _logger = Logger("_CustomTitleBarWindowsAppState");
  
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  bool _isMaximized = false;
  
  @override
  void initState() {
    // check platform: only windows supported
    if (!Platform.isWindows) throw Exception("_CustomTitleBarWindowsAppState: Platform not supported: ${Platform.operatingSystem}");
    
    super.initState();
    windowManager.addListener(this);

    // intercept close requests so that onWindowClose can handle confirmation and shutdownAction
    windowManager.setPreventClose(true);

    // sync window state
    _syncWindowMaximizedState();
  }

  /// Update the _isMaximized property. Pass [windowManagerMaximized] to reduce windowManager.isMaximized() calls
  Future<void> _syncWindowMaximizedState({bool? windowManagerMaximized = null}) async {
    late final bool maximized;
    if (windowManagerMaximized != null) {
      maximized = windowManagerMaximized;
    } else {
      maximized = await windowManager.isMaximized();
    }

    if (mounted && maximized != _isMaximized) {
      setState(() => _isMaximized = maximized);
    }
  }

  /// Maximize the window, or restore it if it is already maximized
  Future<void> _toggleMaximizeWindow() async {
    if (await windowManager.isMaximized()) {
      await windowManager.unmaximize();
      await _syncWindowMaximizedState(windowManagerMaximized: false);
    } else {
      await windowManager.maximize();
      await _syncWindowMaximizedState(windowManagerMaximized: true);
    }
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  ///
  Widget _buildTitleBar(BuildContext context) {
    final theme = Theme.of(context);

    // Wrap in material 
    return Material(
      color: theme.colorScheme.surfaceContainer,
      child: Container(
        height: 36,
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: theme.colorScheme.outlineVariant, width: 1)
          )
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Left: User provided widget. Draggable, double-click toggles maximize
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                // maximize window on double tap
                onDoubleTap: _toggleMaximizeWindow,
                child: DragToMoveArea(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: widget.titleBarWidgetBuilder(context),
                  ),
                ),
              ),
            ),
            // Right: Window controls
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // WND Control: Minimize
                _WindowControlButton(
                  buttonType: _WindowControlButtonType.MINIMIZE,
                  onPressed: windowManager.minimize,
                ),
                // WND Control: toggle maximize / restore
                _WindowControlButton(
                  onPressed: _toggleMaximizeWindow,
                  buttonType: _isMaximized ? _WindowControlButtonType.MAXIMIZE_RESTORE : _WindowControlButtonType.MAXIMIZE,
                ),
                // WND Control: close window
                _WindowControlButton(
                  onPressed: windowManager.close,
                  buttonType: _WindowControlButtonType.CLOSE,
                ),
              ]
            )
          ]
        )
      )
    );
  }

  /// Will use a ListenableBuilder registered to both widget.themeModeNotifier, widget.localeNotifier
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([widget.themeModeNotifier, widget.localeNotifier]),
      builder: (context, _) {
        // create Material App with custom title bar
        return MaterialApp(
          navigatorKey: _navigatorKey,
          title: widget.windowTitle,
          debugShowCheckedModeBanner: false,
          theme: widget.lightTheme,
          darkTheme: widget.darkTheme,
          themeMode: widget.themeModeNotifier.value,
          locale: widget.localeNotifier.value,
          // Inject top bar to the top of the window via builder
          builder: (context, child) {
            return Column(
              children: [
                _buildTitleBar(context),
                Expanded(
                  child: child ?? const SizedBox.shrink(),
                ),
              ],
            );
          },
          // Will be passed as child above
          home: Builder(
            builder: (context) => widget.appContentWidgetBuilder(context),
          ),
        );
      },
    );
  }

  // -----------------------------------------------------------------SHUTDOWN--<
  Completer? _shutdownActionCompleter = null;
  bool _windowCloseActive = false;

  @override
  void onWindowClose() async {
    if (_navigatorKey.currentContext == null || !_navigatorKey.currentContext!.mounted) return;

    // Disallow triggering close/shutdown while confirmation or shutdown is already active
    if ( (_shutdownActionCompleter != null && _shutdownActionCompleter!.isCompleted == false)
      || _windowCloseActive) {
      return;
    }

    // start shutdown procedure
    _windowCloseActive = true;
    try {
      bool canClose = !widget.confirmOnClose;

      // show confirm popup
      if (widget.confirmOnClose) {
        // show main close dialog
        bool userConfirmedClose = false;
        // get user confirmation
        await showDialog(
          context: _navigatorKey.currentContext!,
          builder: (dialogContext) {
            return AlertDialog(
              title: Text("Confirm close?"),
              actions: [
                TextButton(
                  child: Text("No"),
                  onPressed: () => Navigator.of(dialogContext).pop(),
                ),
                TextButton(
                  child: Text("Yes"),
                  onPressed: () {
                    userConfirmedClose = true;
                    Navigator.of(dialogContext).pop();
                  },
                ),
              ],
            );
          },
        );

        canClose = userConfirmedClose; // code will proceed with canClose
      } 
    
      if (!canClose) {
        _logger.fine("onWindowClose(): user did not confirm close");
        return;
      }

      if (widget.shutdownAction != null) {
        // start async close function and configure completer
        if (_shutdownActionCompleter != null) {
          throw Exception("_shutdownActionCompleter cannot be set more than once!");
        }
        _shutdownActionCompleter = Completer();

        final Future shutdownActionFuture = Future.sync(() => widget.shutdownAction!());
        // register callbacks
        shutdownActionFuture.then((_) {
          if (!_shutdownActionCompleter!.isCompleted) {
            _shutdownActionCompleter!.complete();
          }
        }, onError: (e, st) {
          _logger.severe("shutdown action completed with error: $e, $st");
          // Still complete so the shutdown dialog finishes and the app can exit
          if (!_shutdownActionCompleter!.isCompleted) {
            _shutdownActionCompleter!.complete();
          }
        });

        // show loading bar of 5 seconds that hangs until _shutdownActionCompleter completes
        if (_navigatorKey.currentContext != null && _navigatorKey.currentContext!.mounted) {
          showDialog(
            context: _navigatorKey.currentContext!,
            barrierDismissible: false,
            builder: (dialogContext) {
              return PopScope(
                canPop: false,
                child: AlertDialog(
                  title: Text("Please wait"),
                  content: SizedBox(
                    width: 360,
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Placeholder()
                    )
                  )
                ),
              );
            }
          );
        }

        // wait for the given shutdown action to complete
        await _shutdownActionCompleter!.future;
        await Future.delayed(const Duration(milliseconds: 350)); // show final progress bar fill 
      }

      windowManager.removeListener(this);
      try {
        await windowManager.destroy();
      } catch (e, st) {
        _logger.severe("Failed to destroy windowManager instance: $e, $st");
        exit(0);
      }

    } catch (e, st) {
      _logger.severe("onWindowClose failed: $e, $st");
    } finally {
      _windowCloseActive = false;
    }
  }

  // ------------------------------------------------------------WINDOW EVENTS--<

  /// Sync window events from window_manager to UI
  @override
  void onWindowMaximize() => _syncWindowMaximizedState();
  
  /// Sync window events from window_manager to UI
  @override
  void onWindowUnmaximize() => _syncWindowMaximizedState();

  /// Sync window events from window_manager to UI
  @override
  void onWindowRestore() => _syncWindowMaximizedState();
}

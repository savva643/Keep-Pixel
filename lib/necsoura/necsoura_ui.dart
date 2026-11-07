import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Общий вид аккаунта Necsoura во всех приложениях экосистемы (blast!, Kompot, …): один и тот же
/// экран входа, страница аккаунта и вход по QR, у каждого приложения — свой цвет.
/// Файлы lib/necsoura/ одинаковые во всех приложениях: правьте в одном и копируйте в остальные.
class NecsouraBrand {
  /// Как приложение пишется в «Вход в …»
  final String appName;
  /// Значок приложения (квадратный)
  final String appIcon;
  /// Цвет приложения: кнопки, переключатели, подсветка фокуса
  final Color accent;
  /// Второй цвет градиента (панель бренда на широком экране)
  final Color accentDeep;
  /// Шрифт заголовков
  final String fontFamily;

  const NecsouraBrand({
    required this.appName,
    required this.appIcon,
    required this.accent,
    required this.accentDeep,
    this.fontFamily = 'Montserrat',
  });

  static const logo = 'assets/images/necsoura_logo.png';
  static const wordmark = 'assets/images/necsoura_wordmark.png';

  /// Сервисы экосистемы — для подписи сеансов и витрины на экране входа
  static const services = <String, ({String name, String icon})>{
    'blast': (name: 'blast!', icon: 'assets/images/blast_log2.png'),
    'kompot': (name: 'Kompot', icon: 'assets/images/kompot_logo.png'),
    'keeppixel': (name: 'Keep Pixel', icon: 'assets/images/keeppixel_logo.png'),
  };

  static String serviceName(String id) => services[id]?.name ?? (id.isEmpty || id == 'unknown' ? 'Necsoura' : id);
}

/// Знак Necsoura (буква N)
class NecsouraLogo extends StatelessWidget {
  final double size;
  const NecsouraLogo({super.key, this.size = 40});

  @override
  Widget build(BuildContext context) => Image.asset(NecsouraBrand.logo, width: size, height: size, filterQuality: FilterQuality.medium);
}

/// Знак и надпись Necsoura в строку
class NecsouraLockup extends StatelessWidget {
  final double height;
  final Color? color;
  const NecsouraLockup({super.key, this.height = 28, this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        NecsouraLogo(size: height * 1.15),
        SizedBox(width: height * 0.35),
        Image.asset(NecsouraBrand.wordmark, height: height * 0.62, color: color ?? Theme.of(context).colorScheme.onSurface),
      ],
    );
  }
}

/// Фон экранов аккаунта: тёмный с мягкими пятнами цвета приложения, которые медленно плывут
class NecsouraBackdrop extends StatefulWidget {
  final NecsouraBrand brand;
  final Widget child;
  const NecsouraBackdrop({super.key, required this.brand, required this.child});

  @override
  State<NecsouraBackdrop> createState() => _NecsouraBackdropState();
}

class _NecsouraBackdropState extends State<NecsouraBackdrop> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 18))..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final base = dark ? const Color(0xFF0E0E12) : const Color(0xFFF6F5FA);
    return ColoredBox(
      color: base,
      child: Stack(
        children: [
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _c,
              builder: (context, _) {
                final t = Curves.easeInOut.transform(_c.value);
                return DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment(-0.9 + t * 0.5, -1.0 + t * 0.3),
                      radius: 1.1,
                      colors: [widget.brand.accent.withOpacity(dark ? 0.28 : 0.18), base.withOpacity(0)],
                    ),
                  ),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: Alignment(1.0 - t * 0.4, 1.0 - t * 0.2),
                        radius: 1.0,
                        colors: [widget.brand.accentDeep.withOpacity(dark ? 0.22 : 0.12), base.withOpacity(0)],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Positioned.fill(child: widget.child),
        ],
      ),
    );
  }
}

/// Нажимаемое с подсветкой фокуса: на телевизоре и с клавиатуры видно, где курсор
class NecsouraPressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final BorderRadius radius;
  final Color accent;
  final bool autofocus;
  final FocusNode? focusNode;

  const NecsouraPressable({
    super.key,
    required this.child,
    required this.onTap,
    required this.accent,
    this.radius = const BorderRadius.all(Radius.circular(16)),
    this.autofocus = false,
    this.focusNode,
  });

  @override
  State<NecsouraPressable> createState() => _NecsouraPressableState();
}

class _NecsouraPressableState extends State<NecsouraPressable> {
  bool _focused = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    return FocusableActionDetector(
      enabled: enabled,
      autofocus: widget.autofocus,
      focusNode: widget.focusNode,
      onShowFocusHighlight: (v) => setState(() => _focused = v),
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) {
          widget.onTap?.call();
          return null;
        }),
      },
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.select): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
      },
      child: GestureDetector(
        onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
        onTapCancel: () => setState(() => _pressed = false),
        onTapUp: (_) => setState(() => _pressed = false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _pressed ? 0.97 : (_focused ? 1.02 : 1),
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            foregroundDecoration: BoxDecoration(
              borderRadius: widget.radius,
              border: Border.all(color: _focused ? widget.accent : Colors.transparent, width: 2.5),
            ),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

/// Главная кнопка: цвет приложения, при загрузке — крутилка вместо текста
class NecsouraButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final Color accent;
  final bool loading;
  final IconData? icon;
  final bool outlined;
  final bool autofocus;
  final Color? color;

  const NecsouraButton({
    super.key,
    required this.text,
    required this.onPressed,
    required this.accent,
    this.loading = false,
    this.icon,
    this.outlined = false,
    this.autofocus = false,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final enabled = onPressed != null && !loading;
    final fg = outlined ? (color ?? scheme.onSurface) : Colors.white;
    return NecsouraPressable(
      accent: accent,
      autofocus: autofocus,
      radius: BorderRadius.circular(16),
      onTap: enabled ? onPressed : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 54,
        decoration: BoxDecoration(
          color: outlined ? Colors.transparent : (enabled || loading ? (color ?? accent) : scheme.onSurface.withOpacity(0.12)),
          borderRadius: BorderRadius.circular(16),
          border: outlined ? Border.all(color: (color ?? scheme.onSurface).withOpacity(0.22), width: 1.4) : null,
          boxShadow: outlined || !enabled
              ? null
              : [BoxShadow(color: (color ?? accent).withOpacity(0.35), blurRadius: 18, offset: const Offset(0, 6))],
        ),
        alignment: Alignment.center,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          transitionBuilder: (c, a) => FadeTransition(opacity: a, child: ScaleTransition(scale: Tween(begin: 0.8, end: 1.0).animate(a), child: c)),
          child: loading
              ? SizedBox(key: const ValueKey('l'), width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: fg))
              : Row(
                  key: ValueKey(text),
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (icon != null) ...[Icon(icon, color: fg, size: 20), const SizedBox(width: 10)],
                    Text(text, style: TextStyle(color: fg, fontSize: 16, fontWeight: FontWeight.w700, fontFamily: 'Montserrat')),
                  ],
                ),
        ),
      ),
    );
  }
}

/// Поле ввода в стиле Kompot: залитое, скруглённое, рамка цвета приложения в фокусе
class NecsouraField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final Color accent;
  final bool password;
  final TextInputType? keyboardType;
  final TextInputAction? action;
  final ValueChanged<String>? onSubmitted;
  final String? Function(String?)? validator;
  final FocusNode? focusNode;
  final Iterable<String>? autofill;
  final bool autofocus;

  const NecsouraField({
    super.key,
    required this.controller,
    required this.label,
    required this.icon,
    required this.accent,
    this.password = false,
    this.keyboardType,
    this.action,
    this.onSubmitted,
    this.validator,
    this.focusNode,
    this.autofill,
    this.autofocus = false,
  });

  @override
  State<NecsouraField> createState() => _NecsouraFieldState();
}

class _NecsouraFieldState extends State<NecsouraField> {
  bool _hidden = true;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fill = Theme.of(context).brightness == Brightness.dark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.05);
    OutlineInputBorder border(Color c, [double w = 0]) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: w == 0 ? BorderSide.none : BorderSide(color: c, width: w),
        );
    return TextFormField(
      controller: widget.controller,
      focusNode: widget.focusNode,
      autofocus: widget.autofocus,
      obscureText: widget.password && _hidden,
      keyboardType: widget.keyboardType,
      textInputAction: widget.action,
      onFieldSubmitted: widget.onSubmitted,
      validator: widget.validator,
      autofillHints: widget.autofill,
      autocorrect: false,
      enableSuggestions: !widget.password,
      cursorColor: widget.accent,
      style: TextStyle(color: scheme.onSurface, fontSize: 16),
      decoration: InputDecoration(
        labelText: widget.label,
        labelStyle: TextStyle(color: scheme.onSurface.withOpacity(0.55)),
        floatingLabelStyle: TextStyle(color: widget.accent, fontWeight: FontWeight.w600),
        filled: true,
        fillColor: fill,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        border: border(Colors.transparent),
        enabledBorder: border(Colors.transparent),
        focusedBorder: border(widget.accent, 2),
        errorBorder: border(scheme.error, 1.4),
        focusedErrorBorder: border(scheme.error, 2),
        prefixIcon: Icon(widget.icon, color: scheme.onSurface.withOpacity(0.5)),
        suffixIcon: widget.password
            ? IconButton(
                tooltip: _hidden ? 'Показать пароль' : 'Скрыть пароль',
                onPressed: () => setState(() => _hidden = !_hidden),
                icon: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
                  child: Icon(_hidden ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      key: ValueKey(_hidden), color: scheme.onSurface.withOpacity(0.5)),
                ),
              )
            : null,
      ),
    );
  }
}

/// Переключатель «Пароль / QR-код» с плавно переезжающей плашкой
class NecsouraSegmented extends StatelessWidget {
  final List<({IconData icon, String label})> items;
  final int index;
  final ValueChanged<int> onChanged;
  final Color accent;

  const NecsouraSegmented({super.key, required this.items, required this.index, required this.onChanged, required this.accent});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final track = Theme.of(context).brightness == Brightness.dark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.05);
    return Container(
      height: 50,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: track, borderRadius: BorderRadius.circular(16)),
      child: LayoutBuilder(
        builder: (context, c) {
          final w = c.maxWidth / items.length;
          return Stack(
            children: [
              AnimatedPositioned(
                duration: const Duration(milliseconds: 320),
                curve: Curves.easeOutBack,
                left: w * index,
                top: 0,
                bottom: 0,
                width: w,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: accent,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [BoxShadow(color: accent.withOpacity(0.35), blurRadius: 12, offset: const Offset(0, 3))],
                  ),
                ),
              ),
              Row(
                children: [
                  for (var i = 0; i < items.length; i++)
                    Expanded(
                      child: NecsouraPressable(
                        accent: Colors.white,
                        radius: BorderRadius.circular(12),
                        onTap: () => onChanged(i),
                        child: SizedBox.expand(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(items[i].icon, size: 18, color: i == index ? Colors.white : scheme.onSurface.withOpacity(0.6)),
                              const SizedBox(width: 8),
                              AnimatedDefaultTextStyle(
                                duration: const Duration(milliseconds: 200),
                                style: TextStyle(
                                  color: i == index ? Colors.white : scheme.onSurface.withOpacity(0.6),
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                  fontFamily: 'Montserrat',
                                ),
                                child: Text(items[i].label),
                              ),
                            ],
                          ),
                        ),
                      ),
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

/// Круглое фото профиля; нет фото — первая буква имени на цвете приложения
class NecsouraAvatar extends StatelessWidget {
  final String? url;
  final String name;
  final double size;
  final Color accent;

  const NecsouraAvatar({super.key, required this.url, required this.name, required this.accent, this.size = 48});

  @override
  Widget build(BuildContext context) {
    final letter = name.trim().isEmpty ? 'N' : name.trim().characters.first.toUpperCase();
    final fallback = DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(colors: [accent, Color.lerp(accent, Colors.black, 0.35)!], begin: Alignment.topLeft, end: Alignment.bottomRight),
      ),
      child: Center(
        child: Text(letter, style: TextStyle(color: Colors.white, fontSize: size * 0.42, fontWeight: FontWeight.w700, fontFamily: 'Montserrat')),
      ),
    );
    return SizedBox(
      width: size,
      height: size,
      child: ClipOval(
        child: url == null || !url!.startsWith('http')
            ? fallback
            : CachedNetworkImage(imageUrl: url!, fit: BoxFit.cover, placeholder: (_, __) => fallback, errorWidget: (_, __, ___) => fallback),
      ),
    );
  }
}

/// Группа строк настроек со скруглёнными краями, как в настройках Kompot
class NecsouraGroup extends StatelessWidget {
  final String? title;
  final List<Widget> children;
  const NecsouraGroup({super.key, this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final card = Theme.of(context).brightness == Brightness.dark ? Colors.white.withOpacity(0.055) : Colors.white;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (title != null)
          Padding(
            padding: const EdgeInsets.only(left: 6, bottom: 10, top: 6),
            child: Text(title!,
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: scheme.onSurface.withOpacity(0.6), fontFamily: 'Montserrat')),
          ),
        ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: ColoredBox(
            color: card,
            child: Column(
              children: [
                for (var i = 0; i < children.length; i++) ...[
                  if (i > 0) Divider(height: 1, thickness: 1, indent: 56, color: scheme.onSurface.withOpacity(0.06)),
                  children[i],
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 22),
      ],
    );
  }
}

/// Строка в группе: значок, заголовок, подпись и стрелка/переключатель справа
class NecsouraTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color accent;
  final Color? color;
  final bool autofocus;

  const NecsouraTile({
    super.key,
    required this.icon,
    required this.title,
    required this.accent,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.color,
    this.autofocus = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final c = color ?? scheme.onSurface;
    return NecsouraPressable(
      accent: accent,
      radius: BorderRadius.circular(18),
      autofocus: autofocus,
      onTap: onTap,
      child: ColoredBox(
        // Нажимается вся строка, а не только текст
        color: Colors.transparent,
        child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(color: (color ?? accent).withOpacity(0.14), borderRadius: BorderRadius.circular(10)),
                  child: Icon(icon, size: 19, color: color ?? accent),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: TextStyle(fontSize: 16, color: c, fontWeight: FontWeight.w500)),
                      if (subtitle != null && subtitle!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(subtitle!, style: TextStyle(fontSize: 13, color: scheme.onSurface.withOpacity(0.55))),
                      ],
                    ],
                  ),
                ),
                trailing ?? (onTap != null ? Icon(Icons.chevron_right_rounded, color: scheme.onSurface.withOpacity(0.35)) : const SizedBox()),
              ],
            ),
          ),
      ),
    );
  }
}

/// Короткое сообщение снизу
void necsouraToast(BuildContext context, String text, {bool error = false}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  messenger?.hideCurrentSnackBar();
  messenger?.showSnackBar(SnackBar(
    content: Text(text),
    behavior: SnackBarBehavior.floating,
    backgroundColor: error ? Theme.of(context).colorScheme.error : null,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
  ));
}

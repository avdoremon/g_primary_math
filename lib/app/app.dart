import 'package:flutter/material.dart';

import '../screens/profiles_screen.dart';
import '../ui/theme/theme.dart';
import '../ui/widgets/tin_tin.dart';
import 'services.dart';

class ToanVanDongApp extends StatefulWidget {
  const ToanVanDongApp({super.key, this.services});

  /// Truyền sẵn dịch vụ (test); null thì tự khởi động bằng [AppServices.create].
  final AppServices? services;

  @override
  State<ToanVanDongApp> createState() => _ToanVanDongAppState();
}

class _ToanVanDongAppState extends State<ToanVanDongApp> {
  late final Future<AppServices> _services =
      widget.services != null ? Future.value(widget.services!) : AppServices.create();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AppServices>(
      future: _services,
      builder: (context, snap) {
        final services = snap.data;
        return MaterialApp(
          title: 'Toán Vận Động',
          debugShowCheckedModeBanner: false,
          theme: buildTvdTheme(),
          builder: services == null ? null : (context, child) => AppScope(services: services, child: child!),
          home: services != null
              ? const ProfilesScreen()
              : Scaffold(
                  body: Center(
                    child: snap.hasError
                        ? Padding(
                            padding: const EdgeInsets.all(TvdSpace.s5),
                            child: Text('Không khởi động được: ${snap.error}', textAlign: TextAlign.center),
                          )
                        : const TinTin(state: TinTinState.wait, size: 160),
                  ),
                ),
        );
      },
    );
  }
}

import 'package:dart_cast/dart_cast.dart';

class CastService {
  final CastService _inner;

  CastService()
      : _inner = CastService(
          discoveryProviders: [
            DlnaDiscoveryProvider(),
            ChromecastDiscoveryProvider(),
            AirPlayDiscoveryProvider(),
          ],
          sessionFactory: (device) {
            switch (device.protocol) {
              case CastProtocol.chromecast:
                return ChromecastSession(device: device);
              case CastProtocol.airplay:
                return AirPlaySession(device);
              case CastProtocol.dlna:
                throw UnimplementedError('DLNA 需要设备描述，完整用法见 dart_cast 示例');
            }
          },
        );

  Stream<List<CastDevice>> discover() => _inner.startDiscovery();

  Future<CastSession> connect(CastDevice device) => _inner.connect(device);

  Future<void> castVideo(CastSession session, String url) {
    return session.loadMedia(CastMedia(
      url: url,
      type: CastMediaType.hls,
      title: 'Anime',
    ));
  }

  void dispose() => _inner.dispose();
}

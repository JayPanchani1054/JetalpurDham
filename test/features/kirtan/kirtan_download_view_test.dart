import 'package:flutter_test/flutter_test.dart';
import 'package:jetalpur_dham/core/services/download_service.dart';
import 'package:jetalpur_dham/features/kirtan/presentation/widgets/kirtan_download_button.dart';

void main() {
  group('KirtanDownloadView.from', () {
    test('shows progress while downloading', () {
      final KirtanDownloadView view = KirtanDownloadView.from(
        const DownloadState(DownloadStatus.downloading, progress: 0.4),
        indexed: false,
      );
      expect(view.isDownloading, isTrue);
      expect(view.progress, 0.4);
    });

    test('downloaded file wins', () {
      expect(
        KirtanDownloadView.from(
          const DownloadState(DownloadStatus.downloaded),
          indexed: false,
        ).isDownloaded,
        isTrue,
      );
    });

    test('an indexed kirtan counts as downloaded until checked', () {
      expect(
        KirtanDownloadView.from(DownloadState.none, indexed: true).isDownloaded,
        isTrue,
      );
      expect(
        KirtanDownloadView.from(DownloadState.none, indexed: false).status,
        DownloadStatus.notDownloaded,
      );
    });

    test('a failed download offers to download again', () {
      final KirtanDownloadView view = KirtanDownloadView.from(
        const DownloadState(DownloadStatus.failed),
        indexed: true,
      );
      expect(view.isDownloaded, isFalse);
      expect(view.isDownloading, isFalse);
    });
  });
}

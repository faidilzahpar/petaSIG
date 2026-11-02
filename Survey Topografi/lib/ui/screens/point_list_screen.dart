import 'package:flutter/material.dart';
import '../../core/models/topo_dataset.dart';
import '../theme/topo_theme.dart';

class PointListScreen extends StatelessWidget {
  final TopoDataset dataset;
  final VoidCallback onDatasetUpdated;

  const PointListScreen({
    super.key,
    required this.dataset,
    required this.onDatasetUpdated,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('DAFTAR TITIK (${dataset.points.length})'),
        actions: [
          if (dataset.points.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep, color: TopoTheme.alertRed),
              tooltip: 'Hapus Semua Titik',
              onPressed: () {
                _confirmClear(context);
              },
            ),
        ],
      ),
      body: dataset.points.isEmpty
          ? const Center(
              child: Text(
                'Belum ada titik survei yang direkam.',
                style: TextStyle(fontFamily: 'monospace', color: TopoTheme.textMuted),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(8),
              itemCount: dataset.points.length,
              separatorBuilder: (_, __) => const Divider(color: TopoTheme.borderDark, height: 1),
              itemBuilder: (context, index) {
                final pt = dataset.points[index];
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                  leading: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: TopoTheme.cardDark,
                      borderRadius: BorderRadius.circular(2),
                    ),
                    child: Text(
                      pt.code,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                        color: TopoTheme.safetyAmber,
                      ),
                    ),
                  ),
                  title: Text(
                    '${pt.id} | Z: ${pt.groundElevation.toStringAsFixed(3)} m',
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: TopoTheme.textLight,
                    ),
                  ),
                  subtitle: Text(
                    'X: ${pt.localPosition.x.toStringAsFixed(2)} | Y: ${pt.localPosition.y.toStringAsFixed(2)} | σ: ±${pt.rmse.toStringAsFixed(2)}m',
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 10,
                      color: TopoTheme.textMuted,
                    ),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.close, size: 18, color: TopoTheme.textMuted),
                    onPressed: () {
                      dataset.removePoint(pt.id);
                      onDatasetUpdated();
                    },
                  ),
                );
              },
            ),
    );
  }

  void _confirmClear(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: TopoTheme.surfaceDark,
        title: const Text('Hapus Semua Data Titik?'),
        content: const Text('Tindakan ini akan mengosongkan seluruh jaring titik topografi.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: TopoTheme.alertRed),
            onPressed: () {
              dataset.clearPoints();
              onDatasetUpdated();
              Navigator.pop(ctx);
            },
            child: const Text('Hapus', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}


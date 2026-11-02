import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/models/topo_dataset.dart';
import '../../core/export/csv_exporter.dart';
import '../../core/export/geojson_exporter.dart';
import '../../core/export/dxf_exporter.dart';
import '../theme/topo_theme.dart';

class ExportScreen extends StatefulWidget {
  final TopoDataset dataset;

  const ExportScreen({super.key, required this.dataset});

  @override
  State<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends State<ExportScreen> {
  String _selectedFormat = 'CSV';
  String _previewContent = '';

  @override
  void initState() {
    super.initState();
    _updatePreview();
  }

  void _updatePreview() {
    switch (_selectedFormat) {
      case 'CSV':
        _previewContent = CsvExporter.exportPnezd(widget.dataset);
        break;
      case 'GeoJSON':
        _previewContent = GeoJsonExporter.exportGeoJson(widget.dataset);
        break;
      case 'DXF':
        _previewContent = DxfExporter.exportDxf(widget.dataset);
        break;
    }
    setState(() {});
  }

  void _shareOrExport() {
    String filename = 'topo_survey_${widget.dataset.projectName.replaceAll(" ", "_")}.${_selectedFormat.toLowerCase()}';
    Share.share(
      _previewContent,
      subject: 'Data Survei Topografi: $filename',
    );
  }

  void _copyToClipboard() {
    Clipboard.setData(ClipboardData(text: _previewContent));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('✓ Konten $_selectedFormat berhasil disalin ke Clipboard!'),
        backgroundColor: TopoTheme.statusGreen,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('EKSPOR DATA TOPOGRAFI'),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy),
            tooltip: 'Salin ke Clipboard',
            onPressed: _copyToClipboard,
          ),
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: 'Bagikan File',
            onPressed: _shareOrExport,
          ),
        ],
      ),
      body: Column(
        children: [
          // Pilihan Format Ekspor
          Container(
            padding: const EdgeInsets.all(12),
            color: TopoTheme.surfaceDark,
            child: Row(
              children: [
                const Text(
                  'FORMAT:',
                  style: TextStyle(fontFamily: 'monospace', fontSize: 10, fontWeight: FontWeight.bold, color: TopoTheme.textMuted),
                ),
                const SizedBox(width: 10),
                _formatChip('CSV (PNEZD)'),
                const SizedBox(width: 8),
                _formatChip('GeoJSON'),
                const SizedBox(width: 8),
                _formatChip('DXF (AutoCAD)'),
              ],
            ),
          ),

          // Pratinjau Teks Monospace
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: TopoTheme.cardDark,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: TopoTheme.borderDark),
              ),
              child: SingleChildScrollView(
                child: SelectableText(
                  _previewContent.isEmpty ? '// Tidak ada data titik untuk diekspor' : _previewContent,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 10,
                    color: TopoTheme.textLight,
                    height: 1.3,
                  ),
                ),
              ),
            ),
          ),

          // Tombol Aksi Ekspor
          Container(
            padding: const EdgeInsets.all(12),
            color: TopoTheme.surfaceDark,
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _shareOrExport,
                icon: const Icon(Icons.file_download),
                label: Text(
                  'BAGIKAN / SIMPAN FILE $_selectedFormat',
                  style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _formatChip(String label) {
    String key = label.split(' ').first;
    bool isSelected = _selectedFormat == key;
    return GestureDetector(
      onTap: () {
        _selectedFormat = key;
        _updatePreview();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? TopoTheme.safetyAmber : TopoTheme.cardDark,
          borderRadius: BorderRadius.circular(3),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.black : TopoTheme.textLight,
          ),
        ),
      ),
    );
  }
}


import '../models/topo_dataset.dart';

/// Eksportir AutoCAD DXF (Drawing Interchange Format)
/// Menghasilkan layer titik survei, jaring TIN 3DFACE, dan garis kontur 3D.
class DxfExporter {
  static String exportDxf(TopoDataset dataset) {
    final sb = StringBuffer();

    // HEADER SECTION
    sb.writeln('0\nSECTION\n2\nHEADER\n9\n\$ACADVER\n1\nAC1015'); // AutoCAD 2000 format
    sb.writeln('0\nENDSEC');

    // TABLES SECTION (Layers)
    sb.writeln('0\nSECTION\n2\nTABLES\n0\nTABLE\n2\nLAYER');
    _writeLayer(sb, '0', 7); // Default White
    _writeLayer(sb, 'SURVEY_POINTS', 1); // Red
    _writeLayer(sb, 'TIN_SURFACE', 8);   // Dark Grey
    _writeLayer(sb, 'CONTOURS_INTERMEDIATE', 3); // Green
    _writeLayer(sb, 'CONTOURS_INDEX', 4); // Cyan
    sb.writeln('0\nENDTAB\n0\nENDSEC');

    // ENTITIES SECTION
    sb.writeln('0\nSECTION\n2\nENTITIES');

    // 1. Survey Points (POINT Entities)
    for (var p in dataset.points) {
      sb.writeln('0\nPOINT\n8\nSURVEY_POINTS');
      sb.writeln('10\n${p.localPosition.x.toStringAsFixed(3)}');
      sb.writeln('20\n${p.localPosition.y.toStringAsFixed(3)}');
      sb.writeln('30\n${p.groundElevation.toStringAsFixed(3)}');

      // Teks label elevasi
      sb.writeln('0\nTEXT\n8\nSURVEY_POINTS');
      sb.writeln('10\n${(p.localPosition.x + 0.3).toStringAsFixed(3)}');
      sb.writeln('20\n${(p.localPosition.y + 0.3).toStringAsFixed(3)}');
      sb.writeln('30\n${p.groundElevation.toStringAsFixed(3)}');
      sb.writeln('40\n0.35'); // Text height
      sb.writeln('1\n${p.id} (${p.groundElevation.toStringAsFixed(2)}m)');
    }

    // 2. TIN Surface (3DFACE Entities)
    for (var tri in dataset.tinTriangles) {
      sb.writeln('0\n3DFACE\n8\nTIN_SURFACE');
      sb.writeln('10\n${tri.a.x.toStringAsFixed(3)}');
      sb.writeln('20\n${tri.a.y.toStringAsFixed(3)}');
      sb.writeln('30\n${tri.a.z.toStringAsFixed(3)}');

      sb.writeln('11\n${tri.b.x.toStringAsFixed(3)}');
      sb.writeln('21\n${tri.b.y.toStringAsFixed(3)}');
      sb.writeln('31\n${tri.b.z.toStringAsFixed(3)}');

      sb.writeln('12\n${tri.c.x.toStringAsFixed(3)}');
      sb.writeln('22\n${tri.c.y.toStringAsFixed(3)}');
      sb.writeln('32\n${tri.c.z.toStringAsFixed(3)}');

      // Simpul ke-4 sama dengan simpul ke-3 untuk segitiga
      sb.writeln('13\n${tri.c.x.toStringAsFixed(3)}');
      sb.writeln('23\n${tri.c.y.toStringAsFixed(3)}');
      sb.writeln('33\n${tri.c.z.toStringAsFixed(3)}');
    }

    // 3. Contours (LINE Entities)
    for (var c in dataset.contourSegments) {
      sb.writeln('0\nLINE');
      sb.writeln('8\n${c.isIndexContour ? "CONTOURS_INDEX" : "CONTOURS_INTERMEDIATE"}');
      sb.writeln('10\n${c.start.x.toStringAsFixed(3)}');
      sb.writeln('20\n${c.start.y.toStringAsFixed(3)}');
      sb.writeln('30\n${c.elevation.toStringAsFixed(3)}');

      sb.writeln('11\n${c.end.x.toStringAsFixed(3)}');
      sb.writeln('21\n${c.end.y.toStringAsFixed(3)}');
      sb.writeln('31\n${c.elevation.toStringAsFixed(3)}');
    }

    sb.writeln('0\nENDSEC\n0\nEOF');
    return sb.toString();
  }

  static void _writeLayer(StringBuffer sb, String name, int color) {
    sb.writeln('0\nLAYER\n2\n$name\n70\n0\n62\n$color\n6\nCONTINUOUS');
  }
}


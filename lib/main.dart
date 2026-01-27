import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Padron Vista',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1E3A5F),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String? _selectedBarrio;
  String? _selectedLote;
  
  final TextEditingController _tagController = TextEditingController();
  final TextEditingController _patenteController = TextEditingController();

  final List<String> _barrios = ['EC', 'GB', 'MG', 'VL'];
  List<String> _lotes = [];

  Map<String, List<String>> _excelData = {};
  bool _isLoading = true;

  @override
  void dispose() {
    _tagController.dispose();
    _patenteController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    await _initDataFile();
    await _loadExcelData();
  }

  Future<void> _initDataFile() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/PADRONTAG.txt');
      
      if (!await file.exists()) {
        final assetData = await rootBundle.loadString('assets/PADRONTAG.txt');
        await file.writeAsString(assetData);
      }
    } catch (e) {
      debugPrint('Error initializing data file: $e');
    }
  }

  Future<void> _loadExcelData() async {
    try {
      final ByteData data = await rootBundle.load('assets/Lotes Pueblos para accesos fast.xlsx');
      final bytes = data.buffer.asUint8List();
      final excel = Excel.decodeBytes(bytes);

      Map<String, List<String>> tempData = {};

      for (var table in excel.tables.keys) {
        final sheet = excel.tables[table];
        if (sheet != null) {
          for (var row in sheet.rows) {
            if (row.length >= 2) {
              final colA = row[0]?.value?.toString().trim() ?? '';
              final colB = row[1]?.value?.toString().trim() ?? '';
              
              if (colA.isNotEmpty && colB.isNotEmpty) {
                if (!tempData.containsKey(colA)) {
                  tempData[colA] = [];
                }
                if (!tempData[colA]!.contains(colB)) {
                  tempData[colA]!.add(colB);
                }
              }
            }
          }
        }
        break;
      }

      setState(() {
        _excelData = tempData;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      debugPrint('Error loading Excel: $e');
    }
  }

  void _updateLotes() {
    if (_selectedBarrio != null && _excelData.containsKey(_selectedBarrio)) {
      _lotes = _excelData[_selectedBarrio]!;
    } else {
      _lotes = [];
    }
    _selectedLote = null;
  }

  Future<void> _scanTag() async {
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (context) => const TagScannerPage(),
      ),
    );

    if (result != null) {
      final digitsOnly = result.replaceAll(RegExp(r'[^0-9]'), '');
      
      if (digitsOnly.length >= 5) {
        setState(() {
          _tagController.text = digitsOnly;
        });
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('El tag debe tener al menos 5 dígitos'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _scanPatente() async {
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (context) => const PatenteScannerPage(),
      ),
    );

    if (result != null && result.isNotEmpty) {
      setState(() {
        _patenteController.text = result;
      });
    }
  }

  Future<File> _getDataFile() async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/PADRONTAG.txt');
  }

  Future<void> _guardarDatos() async {
    if (_selectedBarrio == null || _selectedLote == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Debe seleccionar Barrio y Lote'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final tag = _tagController.text.trim();
    if (tag.isEmpty || tag.length < 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('El Tag es obligatorio y debe tener al menos 5 dígitos'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      final file = await _getDataFile();
      final clubLote = '$_selectedBarrio$_selectedLote';
      final patente = _patenteController.text.trim();
      final linea = '$clubLote|$tag|$patente\n';

      await file.writeAsString(linea, mode: FileMode.append);
      debugPrint('Guardado en: ${file.path}');
      debugPrint('Línea: $linea');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Guardado: $linea'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );

        setState(() {
          _tagController.clear();
          _patenteController.clear();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _compartirArchivo() async {
    debugPrint('=== INICIANDO COMPARTIR ARCHIVO ===');
    try {
      debugPrint('Obteniendo archivo...');
      final file = await _getDataFile();
      debugPrint('Ruta del archivo: ${file.path}');
      
      final exists = await file.exists();
      debugPrint('¿Archivo existe?: $exists');
      
      if (!exists) {
        debugPrint('ERROR: El archivo no existe');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No hay registros para enviar'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      final contenido = await file.readAsString();
      debugPrint('Contenido del archivo: $contenido');
      debugPrint('Tamaño: ${contenido.length} caracteres');
      
      debugPrint('Intentando compartir...');
      final result = await Share.shareXFiles(
        [XFile(file.path)],
        text: 'PADRONTAG - Registros',
      );
      debugPrint('Resultado compartir: ${result.status}');
      debugPrint('=== FIN COMPARTIR ARCHIVO ===');
    } catch (e, stackTrace) {
      debugPrint('=== ERROR AL COMPARTIR ===');
      debugPrint('Error: $e');
      debugPrint('StackTrace: $stackTrace');
      debugPrint('=== FIN ERROR ===');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al compartir: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'PADRON VISTA',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFF1E3A5F),
        foregroundColor: Colors.white,
        elevation: 4,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFFF5F7FA),
                    Color(0xFFE4E8ED),
                  ],
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 20),
                    _buildDropdown(
                      label: 'Barrio',
                      value: _selectedBarrio,
                      items: _barrios,
                      onChanged: (value) {
                        setState(() {
                          _selectedBarrio = value;
                          _updateLotes();
                        });
                      },
                    ),
                    const SizedBox(height: 20),
                    _buildSearchableField(
                      label: 'Lote',
                      value: _selectedLote,
                      items: _lotes,
                      onSelected: (value) {
                        setState(() {
                          _selectedLote = value;
                        });
                      },
                    ),
                    const SizedBox(height: 20),
                    _buildEditableScannerField(
                      label: 'Tag *',
                      controller: _tagController,
                      icon: Icons.qr_code_scanner_rounded,
                      onScan: _scanTag,
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 20),
                    _buildEditableScannerField(
                      label: 'Patente (opcional)',
                      controller: _patenteController,
                      icon: Icons.camera_alt_rounded,
                      onScan: _scanPatente,
                      keyboardType: TextInputType.text,
                      textCapitalization: TextCapitalization.characters,
                    ),
                    const SizedBox(height: 40),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _guardarDatos,
                            icon: const Icon(Icons.save),
                            label: const Text(
                              'Guardar',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1E3A5F),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 3,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _compartirArchivo,
                            icon: const Icon(Icons.send),
                            label: const Text(
                              'Enviar',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF25D366),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildDropdown({
    required String label,
    required String? value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: DropdownButtonFormField<String>(
        value: value,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(
            color: Color(0xFF546E7A),
            fontWeight: FontWeight.w500,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
        ),
        dropdownColor: Colors.white,
        icon: const Icon(
          Icons.keyboard_arrow_down_rounded,
          color: Color(0xFF1E3A5F),
        ),
        items: items.map((String item) {
          return DropdownMenuItem<String>(
            value: item,
            child: Text(
              item,
              style: const TextStyle(
                color: Color(0xFF37474F),
                fontWeight: FontWeight.w500,
              ),
            ),
          );
        }).toList(),
        onChanged: items.isEmpty ? null : onChanged,
      ),
    );
  }

  Widget _buildSearchableField({
    required String label,
    required String? value,
    required List<String> items,
    required ValueChanged<String> onSelected,
  }) {
    return GestureDetector(
      onTap: items.isEmpty
          ? null
          : () => _showSearchDialog(label, items, onSelected),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            labelStyle: const TextStyle(
              color: Color(0xFF546E7A),
              fontWeight: FontWeight.w500,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
            suffixIcon: const Icon(
              Icons.search_rounded,
              color: Color(0xFF1E3A5F),
            ),
          ),
          child: Text(
            value ?? '',
            style: TextStyle(
              color: value != null ? const Color(0xFF37474F) : const Color(0xFF9E9E9E),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEditableScannerField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    required VoidCallback onScan,
    TextInputType keyboardType = TextInputType.text,
    TextCapitalization textCapitalization = TextCapitalization.none,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        textCapitalization: textCapitalization,
        style: const TextStyle(
          color: Color(0xFF37474F),
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(
            color: Color(0xFF546E7A),
            fontWeight: FontWeight.w500,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
          suffixIcon: IconButton(
            icon: Icon(icon, color: const Color(0xFF1E3A5F)),
            onPressed: onScan,
            tooltip: 'Escanear',
          ),
        ),
      ),
    );
  }

  void _showSearchDialog(String label, List<String> items, ValueChanged<String> onSelected) {
    showDialog(
      context: context,
      builder: (context) => _SearchDialog(
        title: label,
        items: items,
        onSelected: (value) {
          onSelected(value);
          Navigator.pop(context);
        },
      ),
    );
  }
}

class _SearchDialog extends StatefulWidget {
  final String title;
  final List<String> items;
  final ValueChanged<String> onSelected;

  const _SearchDialog({
    required this.title,
    required this.items,
    required this.onSelected,
  });

  @override
  State<_SearchDialog> createState() => _SearchDialogState();
}

class _SearchDialogState extends State<_SearchDialog> {
  final TextEditingController _searchController = TextEditingController();
  List<String> _filteredItems = [];

  @override
  void initState() {
    super.initState();
    _filteredItems = widget.items;
  }

  void _filterItems(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredItems = widget.items;
      } else {
        _filteredItems = widget.items
            .where((item) => item.toLowerCase().contains(query.toLowerCase()))
            .toList();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: double.maxFinite,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Buscar ${widget.title}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E3A5F),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _searchController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Escriba para buscar...',
                  prefixIcon: const Icon(Icons.search, color: Color(0xFF1E3A5F)),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF1E3A5F), width: 2),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                onChanged: _filterItems,
              ),
            ),
            const SizedBox(height: 8),
            Flexible(
              child: _filteredItems.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'No se encontraron resultados',
                        style: TextStyle(color: Color(0xFF9E9E9E)),
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: _filteredItems.length,
                      itemBuilder: (context, index) {
                        final item = _filteredItems[index];
                        return ListTile(
                          title: Text(
                            item,
                            style: const TextStyle(
                              color: Color(0xFF37474F),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          onTap: () => widget.onSelected(item),
                          hoverColor: const Color(0xFFE3F2FD),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.all(8),
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Cancelar',
                  style: TextStyle(color: Color(0xFF1E3A5F)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class TagScannerPage extends StatefulWidget {
  const TagScannerPage({super.key});

  @override
  State<TagScannerPage> createState() => _TagScannerPageState();
}

class _TagScannerPageState extends State<TagScannerPage> {
  final MobileScannerController _controller = MobileScannerController();
  bool _isScanned = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Escanear Tag'),
        backgroundColor: const Color(0xFF1E3A5F),
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: (capture) {
              if (_isScanned) return;
              
              final List<Barcode> barcodes = capture.barcodes;
              for (final barcode in barcodes) {
                final String? code = barcode.rawValue;
                if (code != null && code.isNotEmpty) {
                  _isScanned = true;
                  Navigator.pop(context, code);
                  break;
                }
              }
            },
          ),
          Center(
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 3),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          Positioned(
            bottom: 100,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Apunte al código del tag',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class PatenteScannerPage extends StatefulWidget {
  const PatenteScannerPage({super.key});

  @override
  State<PatenteScannerPage> createState() => _PatenteScannerPageState();
}

class _PatenteScannerPageState extends State<PatenteScannerPage> {
  final ImagePicker _picker = ImagePicker();
  final TextRecognizer _textRecognizer = TextRecognizer();
  bool _isProcessing = false;
  String? _recognizedText;

  @override
  void dispose() {
    _textRecognizer.close();
    super.dispose();
  }

  Future<void> _takePicture() async {
    setState(() {
      _isProcessing = true;
    });

    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.rear,
      );

      if (photo != null) {
        final inputImage = InputImage.fromFilePath(photo.path);
        final RecognizedText recognizedText = await _textRecognizer.processImage(inputImage);

        String patente = _extractPatente(recognizedText.text);
        
        setState(() {
          _recognizedText = patente.isNotEmpty ? patente : null;
          _isProcessing = false;
        });

        if (patente.isNotEmpty && mounted) {
          _showConfirmDialog(patente);
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No se pudo reconocer la patente. Intente de nuevo.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } else {
        setState(() {
          _isProcessing = false;
        });
      }
    } catch (e) {
      setState(() {
        _isProcessing = false;
      });
      debugPrint('Error processing image: $e');
    }
  }

  String _extractPatente(String text) {
    final cleanText = text.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    
    final RegExp newFormat = RegExp(r'[A-Z]{2}[0-9]{3}[A-Z]{2}');
    final RegExp oldFormat = RegExp(r'[A-Z]{3}[0-9]{3}');
    
    final newMatch = newFormat.firstMatch(cleanText);
    if (newMatch != null) {
      return newMatch.group(0) ?? '';
    }
    
    final oldMatch = oldFormat.firstMatch(cleanText);
    if (oldMatch != null) {
      return oldMatch.group(0) ?? '';
    }
    
    if (cleanText.length >= 6 && cleanText.length <= 7) {
      return cleanText;
    }
    
    return '';
  }

  void _showConfirmDialog(String patente) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Patente detectada',
          style: TextStyle(color: Color(0xFF1E3A5F)),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('¿Es correcta esta patente?'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F7FA),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                patente,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                  color: Color(0xFF1E3A5F),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('Reintentar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context, patente);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E3A5F),
              foregroundColor: Colors.white,
            ),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Escanear Patente'),
        backgroundColor: const Color(0xFF1E3A5F),
        foregroundColor: Colors.white,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFF5F7FA),
              Color(0xFFE4E8ED),
            ],
          ),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.camera_alt_rounded,
                  size: 100,
                  color: const Color(0xFF1E3A5F).withOpacity(0.5),
                ),
                const SizedBox(height: 32),
                const Text(
                  'Tome una foto de la patente',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF37474F),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Asegúrese de que la patente esté bien iluminada y enfocada',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF78909C),
                  ),
                ),
                const SizedBox(height: 40),
                _isProcessing
                    ? const CircularProgressIndicator(
                        color: Color(0xFF1E3A5F),
                      )
                    : ElevatedButton.icon(
                        onPressed: _takePicture,
                        icon: const Icon(Icons.camera_alt),
                        label: const Text('Tomar Foto'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1E3A5F),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 32,
                            vertical: 16,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                const SizedBox(height: 24),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'Omitir',
                    style: TextStyle(color: Color(0xFF78909C)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

# INFORME TÉCNICO COMPLETO - EMAP

**Proyecto:** EMAP - Extracción de Aportaciones desde Estados de Ahorro Previsional (PDF a Excel)
**Fecha de generación:** 02/10/2026 10:29:44
**Nota:** Este informe describe el funcionamiento SIN modificar el sistema.

## 1. RESUMEN EJECUTIVO

EMAP es una aplicación de escritorio desarrollada en **Flutter (Dart)** para Windows, cuyo objetivo es extraer información de **Estados de Ahorro Previsional (Gestora Pública de Bolivia)** en formato PDF y convertirla a un **archivo Excel (.xlsx)** con estructura normalizada.

El proceso es: carga/arrastre de PDFs → extracción de texto con **pdfrx (Pdfium)** → análisis no posicional con **PdfParser** → filtrado por empleador (EMAP) → generación de registros → exportación a Excel con logos → persistencia local del historial.

No se realizan modificaciones al sistema; solo se documenta el funcionamiento tal como está implementado.

## 2. DIVISIÓN DEL PROYECTO Y ESTRUCTURA DE CARPETAS

Raíz: C:\Users\Aldo\Desktop\emap\emap\

`
lib/
  app/                → Configuración global (tema, app)
  models/             → Modelos de datos (DTOs)
  resources/          → Recursos (vacío actualmente)
  services/           → Servicios (lógica de negocio/infra)
  utils/              → Utilidades (parsers, helpers)
  views/              → Interfaz de usuario
    procesar/         → Vista principal de procesamiento
`

### 2.1 lib/app/
- pp.dart (lib/app/app.dart:1-18): Define EmapApp (StatelessWidget). MaterialApp con 	itle, debugShowCheckedModeBanner: false, 	heme: AppTheme.light(), home: const ProcesarView().
- 	heme.dart (lib/app/theme.dart): Define tema visual AppTheme.light() (colores, estilos). No se lee en detalle aquí para no modificar; se menciona por contexto.

### 2.2 lib/models/
- egistro_extraido.dart (lib/models/registro_extraido.dart:1-85+): Modelo RegistroExtraido (fila a exportar). Campos: archivo, ci, nombres, cua, empleador, mes, anio, totalGanado, aportesAfp, liquidoPagable, diasTrabajados, fechaProceso, requiereRevision. Métodos: 	oJson(), romJson(), 
ombreMes(), normalización de días, getter esEmpleadorEmap (compara empleador.trim().toUpperCase() con empleadorEmap = 'ENTIDAD MUNICIPAL DE ASEO POTOSI').

### 2.3 lib/services/
- pdf_processing_service.dart (lib/services/pdf_processing_service.dart:1-35): Capa de extracción de texto PDF.
  - extractText(String filePath): Abre PDF con PdfDocument.openFile(filePath) (pdfrx), itera páginas, llama page.loadText() y concatena 	ext.fullText por página (con saltos). Cierra documento con dispose().
  - parsePdfFile(String filePath): Verifica existencia, obtiene texto completo, retorna PdfParser.parse(text).
  - esEscaneado(String filePath): Estima si escaneado (útil < 40 caracteres tras eliminar espacios). Usa RegExp(r'\s+') para conteo.
- historial_service.dart: (mencionado en vista) Servicio para cargar/guardar historial de registros en disco (persistencia local). Usado por ProcesarView (_historial.cargar(), _historial.guardar(_registros)).
- export_service.dart (lib/services/export_service.dart:1-757): Generación de XLSX (generarXlsxBytes, _buildExcel), exportación con selector de ruta (exportarXlsx), cálculo de resúmenes (calcularResumenAportes, estructuras ResumenCertificadoAportes, ResumenAnualAportes), inserción de logos (_agregarLogos), estilos y formato de celdas. Exporta hoja "Certificado".

### 2.4 lib/utils/
- pdf_parser.dart (lib/utils/pdf_parser.dart:1-357): Núcleo de análisis del texto PDF. Contiene clases ParsedPayment, ParsedResult y PdfParser con todos los métodos de reconocimiento/normalización/extracción de tablas y datos del asegurado.

### 2.5 lib/views/
- procesar/procesar_view.dart (lib/views/procesar/procesar_view.dart:1-~fin): UI principal. Gestiona selección (file_picker), arrastre (desktop_drop), procesamiento por lote, filtrado (movimiento.empleador.trim().toUpperCase() == RegistroExtraido.empleadorEmap), cálculo de aportes (portesAfp = totalGanado * 0.1271), determinación integra, construcción de RegistroExtraido, historial, exportar Excel, limpiar.

### 2.6 Otros archivos relevantes
- pubspec.yaml: Dependencias y configuración (ver sección 4).
- main.dart (lib/main.dart:1-23): Punto de entrada. Inicializa Flutter, configura ventana con window_manager (tamaño 1280x760, mínimo 1100x680, ícono ssets/logos/app_icon.ico en Windows), llama unApp(const EmapApp()).
- ssets/logos/: Logos usados en exportación Excel.

## 3. PUNTO DE ENTRADA Y FLUJO DE EJECUCIÓN

1. main() (lib/main.dart:7-23)
   - WidgetsFlutterBinding.ensureInitialized()
   - windowManager.ensureInitialized()
   - WindowOptions(size: Size(1280,760), minimumSize: Size(1100,680), center: true, title: 'EMAP - Extracción de Aportaciones (PDF)')
   - windowManager.waitUntilReadyToShow(...): en Windows establece ícono ssets/logos/app_icon.ico, show(), ocus()
   - unApp(const EmapApp())

2. EmapApp (lib/app/app.dart): MaterialApp → ProcesarView()

3. ProcesarView (estado inicial)
   - _pdfService = PdfProcessingService(), _historial = HistorialService()
   - _registros = [], flags _procesando, _dragOver, _error
   - initState() llama _cargarHistorial() (lee historial persistido)

4. Carga de PDFs (UI)
   - Botón "Seleccionar PDFs": FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['pdf'], allowMultiple: true) → obtiene lista de rutas
   - Drag&Drop: desktop_drop recibe List<DropItem> → filtra .pdf (case-insensitive)
   Ambos llaman _procesarArchivos(List<({File archivo, String nombre})>)

5. Procesamiento por archivo (_procesarArchivos)
   - Para cada ítem: wait _pdfService.parsePdfFile(item.archivo.path) → retorna ParsedResult
   - Filtra esultado.movimientos donde movimiento.empleador.trim().toUpperCase() == RegistroExtraido.empleadorEmap (ENTIDAD MUNICIPAL DE ASEO POTOSI)
   - Si vacío: agrega línea de error al buffer _error ("no se identificaron movimientos de ...")
   - Si hay movimientos: obtiene segurado (mapa CI/nombres/apellidos/CUA...), fecha proceso DateTime.now() (formato yyyy-MM-dd), por cada movimiento:
     - portesAfp = movimiento.totalGanado * 0.1271 (constante 12.71%)
     - cotizacionPdf = movimiento.cotizacionMensual
     - integra = (cotizacionPdf <= 0 || (cotizacionPdf - movimiento.totalGanado*0.10).abs() <= 0.5)  (heurística: integra si cotización mensual <=0 o diferencia con 10% del total ganado <= 0.5)
     - crea RegistroExtraido con campos calculados: liquidoPagable = movimiento.totalGanado - aportesAfp, equiereRevision = movimiento.requiereRevision || !integra
   - Inserta nuevos registros al inicio (_registros.insertAll(0, nuevos))
   - Guarda historial: wait _historial.guardar(_registros)
   - Muestra errores en SnackBar (_notify)

6. Exportación
   - _exportarExcel(): ExportService.exportarXlsx(_registros, 'EMAP_Aportes') → abre FilePicker para guardar (.xlsx), genera bytes con generarXlsxBytes, escribe archivo, retorna ruta y muestra SnackBar.

7. Limpieza
   - _limpiar(): diálogo de confirmación → limpia lista → guarda historial.

## 4. LIBRERÍAS Y DEPENDENCIAS (pubspec.yaml)

Versión app: 1.0.1+2. SDK: ^3.12.2. Flutter Material.

### 4.1 Dependencias de producción

| Librería | Versión | Uso exacto en código | Referencias |
|---|---|---|---|
| lutter | sdk | Framework base. UI, widgets, MaterialApp, etc. | lib/main.dart, lib/app/*, lib/views/* |
| rchive | ^3.6.1 | Manejo/edición de ZIP/XLSX (paquetes Office Open XML). Usado para modificar XLSX añadiendo logos (imágenes embebidas en el archivo Excel). | ExportService._agregarLogos usa Archive, ArchiveFile, ZipEncoder (lib/services/export_service.dart) |
| ile_picker | ^8.1.4 | Diálogo nativo para seleccionar archivos y guardar archivos. | Selección múltiple PDFs: FilePicker.platform.pickFiles (procesar_view.dart:~80-99). Guardar XLSX: FilePicker.platform.saveFile (export_service.dart:~95-125) |
| excel | ^4.0.6 | Generación y escritura de hojas Excel (.xlsx). | Creación Excel.createExcel(), hojas, estilos (CellStyle, borders, colores), columnas, filas/celdas en _buildExcel (export_service.dart:~140-700+). También lectura/uso de bytes. |
| path_provider | ^2.1.5 | Obtención de directorios del sistema (temporal/documentos) para guardar/leer archivos. | Presente en dependencias (pubspec.yaml). Usado implícitamente para rutas en persistencia/exportación (común con file_picker/path). |
| path | ^1.9.0 | Manipulación de rutas (join, basename, extensión). | Utilidades de rutas (pubspec.yaml). |
| pdfrx | ^2.4.0 | Extracción de texto desde PDF mediante Pdfium (nativo). API para abrir documento, páginas y page.loadText() → PdfText.fullText. | PdfDocument.openFile, doc.pages, page.loadText() en PdfProcessingService.extractText (pdf_processing_service.dart:13-30) |
| window_manager | ^0.4.3 | Gestión de ventana de escritorio (tamaño, posición, ícono, foco, título). | Configuración ventana en main.dart (windowOptions, waitUntilReadyToShow, setIcon/show/focus) |
| desktop_drop | ^0.8.4 | Arrastre y soltado (Drag & Drop) de archivos en escritorio. | DropTarget/DesktopDrop en ProcesarView (_recibirArchivos, manejo _dragOver) (procesar_view.dart:~60-140) |

### 4.2 Dev dependencies
- lutter_lints: ^6.0.0 (análisis estático)
- lutter_test: sdk: flutter

### 4.3 Assets
- ssets/logos/ → usados para logos en Excel (ExportService._agregarLogos).

### 4.4 Notas sobre librerías clave (reconocimiento de tablas)
El reconocimiento **NO** usa OCR ni posiciones X/Y fijas. Se basa en:
- Extracción de texto plano por páginas con pdfrx (estructura lineal por líneas).
- Normalización y análisis con regex/heurísticas en PdfParser (ver sección 5).

## 5. CÓMO SE RECONOCEN LAS TABLAS (MECANISMO DETALLADO)

Este es el punto crítico solicitado. El reconocimiento de movimientos/tablas se realiza **completamente en PdfParser** (lib/utils/pdf_parser.dart), sobre el texto extraído por pdfrx.

### 5.1 Estructuras de datos (Parsed*)

- ParsedPayment (líneas ~1-50): Representa una fila/movimiento extraído del PDF (aporte/comisión). Campos: empleador, mes, nio, 	ipoMovimiento ('APORTE_LABORAL'|'COMISION'), 	otalGanado, diasTrabajados, porteAfp, liquidoPagable, cotizacionMensual, porteVoluntario, porteBeneficioSocial, comision, 	otalAportes, alorCuota, 	otalNumeroCuotas, echaPago, equiereRevision.
- ParsedResult (líneas ~52-57): { asegurado: Map<String,String>, movimientos: List<ParsedPayment> }.

### 5.2 Constantes y regex

Definidas en PdfParser (líneas ~60-120 aprox.):

- _months (mapa meses): mapea abreviaturas 3-letras (case-insensitive) a números 1-12: ene,feb,mar,abr,may,jun,jul,ago,sep,oct,nov,dic, jan, dec.
- _mesesList: nombres completos para conversión.
- _monthPeriodRe = RegExp(r'\b([A-Za-z]{3,9})-(\d{4})\b', caseSensitive: false) → detecta periodo tipo "Abr-2024", "FEB-2026".
- _dateRe = RegExp(r'\b(\d{1,2})/(\d{1,2})/(\d{4})\b') → "15/05/2024".
- _numTokenRe = RegExp(r'^-?[\d][\d.,]*$') → token numérico puro (con coma/punto y signo).
- _numRe = RegExp(r'-?[\d][\d.,]*') → extrae números dentro de texto.

### 5.3 Normalización numérica (
um)

Método static double num(Object? s) (líneas ~95-155). Convierte cadenas con formato latino/boliviano a double (punto decimal). Reglas:

1. Limpia no numéricos: 	.replaceAll(RegExp(r'[^\d.,\-]'), '')
2. Formato miles con punto + decimales con coma: ^-?\d+(?:\.\d{3})+(,\d+)?$ → reemplaza . por vacío, , por . → ej. "6.800,55" → 6800.55, "6.800" → 6800
3. Formato miles con coma + decimales con punto: ^-?\d+(?:,\d{3})+(\.\d+)?$ → reemplaza , por vacío → ej. "5,817.67" → 5817.67, "5,817" → 5817
4. Si ambos presentes: separador decimal es el **último** (lastComma vs lastDot). Si coma > punto → decimal coma: "6.800,55" → quita puntos, coma→punto. Si punto > coma → decimal punto: "5,817.67" → quita comas.
5. Solo coma → trata como decimal: 	.replaceAll(',', '.') (caso "680,06" → 680.06)
6. Retorna double.tryParse(t) ?? 0

### 5.4 Normalización de líneas

static List<String> _normalizeLines(String text) (líneas ~190-200):
- Reemplaza \r → \n
- Colapsa espacios/tabs: RegExp(r'[ \t]+') → espacio
- Divide por \n, trim, elimina vacías. Resultado = lista de líneas limpias en orden secuencial (orden de lectura PDF).

### 5.5 Extracción de datos del asegurado

static Map<String,String> _extractAsegurado(List<String> lines) (líneas ~202-270):
Une todas líneas con \n (joined) y aplica regex sobre bloque completo:

- **Nombres y Apellidos**: RegExp(r'Nombres\s+y\s+Apellidos:\s*([A-ZÁÉÍÓÚÜÑ"%'�\s0-9][A-ZÁÉÍÓÚÜÑ"%'�\s0-9 ]*)', caseSensitive: false) → grupo 1. Se divide por espacios: si >=2 → 
ombres = palabras[0]+" "+palabras[1], pellidos = sublist(2).join(' '); si 1 → nombres=palabra, apellidos vacío.
- **Cédula/Documento**: patrón flexible (?:C\.?I\.?|Cedula|C�dula|Documento\s+de\s+Identidad|Doc\.?\s*Identidad|N\.?\s*Doc)[:\s]*(?:[A-ZÁÉÍÓÚÜÑ']+[\s\-]*)?(\d{4,12}) (case-insensitive) → grupo 1 = número CI.
- **CUA**: (?:CUA|Cuenta\s+Única|cuenta\s+unica)[:\s#]*([A-Za-z0-9\-]{6,}) → grupo 1.
- **Número de Estado de Ahorro**: \bdel\s+[Ee]stado\s+[Dd]e\s+[Aa]horro\s+([A-Za-z0-9\-]{8,}) → grupo 1 (
umero).
- **Fecha de Emisión**: Fecha\s+de\s+(?:Emisi[oó]n|Emision)[^\d]*(\d{1,2}[-/]\d{1,2}[-/]\d{2,4}) → parsea con parseDate() (convierte año 2 dígitos a 20xx, devuelve yyyy-MM-dd).
- **Periodo**: Periodo(?:\s+del\s+Estado\s+de\s+Ahorro)?\s*(\d{1,2}/\d{4}(?:\s*a\s+\d{1,2}/\d{4})?) → grupo 1.

Valores por defecto vacíos. No requiere posiciones fijas (busca por etiquetas).

### 5.6 Detección de líneas con periodo y empleadores

- _lineHasPeriod(String line) (línea ~272): parsePeriod(line) != null
- _isEmployerLine(String line) (líneas ~274-277): 
  - regex ^[A-ZÁÉÍÓÚÜÑ"'%�\s][A-ZÁÉÍÓÚÜÑ"'%�\s0-9&.\- ]{3,}$ (mayúsculas/acentos, longitud >=4) 
  - **AND** !_lineHasPeriod(line) (no contiene periodo) → heurística para identificar línea de nombre de empleador (antes de fila de movimiento)

### 5.7 Split de filas de movimiento (construcción de bloques/fila)

static List<String> _splitMovementRows(List<String> section) (líneas ~279-320): Agrupa líneas sueltas en **filas completas de tabla** (cada movimiento puede ocupar 1 o más líneas en texto PDF, pero se consolida).

Algoritmo con buffer:

- uf = StringBuffer(), ows = <String>[], lush() añade uf.trim() a rows y limpia.
- Por cada line en sección:
  - hasPeriod = _lineHasPeriod(line) (contiene "Abr-2024" etc.)
    - Si hasPeriod: si buffer no vacío → escribe \n + línea (acumula continuación debajo del periodo). Si vacío → escribe línea.
  - Else if _isEmployerLine(line): si buffer no vacío → lush() (cierra fila anterior), luego escribe línea (inicia nueva fila con empleador).
  - Else: si buffer no vacío → uf.write('\n') (acumula línea de continuación dentro del mismo bloque/fila)
- lush() final.
- Filtrado post-split:
  - descarta si contiene "total ganado" y **NO** tiene periodo → evita totales/resúmenes
  - descarta si contiene "empleador / tipo de movimiento" → evita encabezados de tabla
  - resto se mantiene

**Importante:** Esto reconstruye la **fila lógica de la tabla** (empleador + periodo + fecha + columnas numéricas) aunque el PDF la haya partido en líneas.

### 5.8 Parseo de bloque/fila

Existen dos métodos complementarios (ambos buscan extraer movimiento):

#### (A) _parseBlock(String block) (líneas ~322-375)
Usa extracción por **etiquetas/palabras clave** dentro del bloque (más tolerante a reordenamientos/parsing por campos). Busca:
- Periodo: parsePeriod(block) (obligatorio)
- Empleador: RegExp(r'([A-ZÁÉÍÓÚÜÑ"'%�\s][A-ZÁÉÍÓÚÜÑ"'%�\s0-9&.\-/ ]{3,})').firstMatch(block) (primera coincidencia larga en mayúsculas)
- Fecha: RegExp(r'(\d{1,2}[-/]\d{1,2}[-/]\d{2,4})').firstMatch(block)
- Campos numéricos por etiquetas (case-insensitive):
  - 	otalGanado: (?:total\s+ganado|ingreso\s+cotizable|total\s+ganado\s+o\s+ingreso)[:\s]*([\d., ]+)
  - diasTrabajados: (?:^|\s)(\d{1,2})\s*(?:d[ií]as)?(?:\s|$) (1-2 dígitos)
  - porteAfp: (?:aporte\s+)?(?:a\.?f\.?p\.?|afp)[:\s]*([\d., ]+)
  - liquidoPagable: (?:l[ií]quido\s+(?:pagable|a\s+pagar|neto)|neto\s+(?:a\s+)?(?:pagar|pagable)|liquido\s+pagado)[:\s]*([\d., ]+)
  - cotizacionMensual: cotizaci[oó]n\s+mensual[:\s]*([\d., ]+)
  - porteVoluntario: porte\s+voluntario[:\s]*([\d., ]+)
  - porteBeneficioSocial: (?:aporte\s+)?beneficio\s+social[:\s]*([\d., ]+)
  - comision: (?:comisi[oó]n|aporte\s+comisi[oó]n)[:\s]*([\d., ]+)
  - 	otalAportes: 	otal\s+aportes[:\s]*([\d., ]+)
  - alorCuota: alor\s+cuota[:\s]*([\d., ]+)
  - 	otalNumeroCuotas: 	otal\s+n[úu]mero\s+de\s+cuotas[:\s]*([\d., ]+)
- 	ipoMovimiento: isCommission(block) ? 'COMISION' : 'APORTE_LABORAL'

#### (B) _parseMovementLine(String line) (líneas ~377-~470) — **método clave para formato tabular**
Este parsea **la fila tal como sale estructurada en tabla** (columnas separadas por espacios). Es el que mejor se ajusta al formato típico del "Estado de Ahorro Previsional".

Pasos:

1. Extrae periodo: pm = _monthPeriodRe.firstMatch(line) → ([A-Za-z]{3,9})-(\d{4}). Obtiene mes, nio vía _months. Requiere periodo válido.
2. Busca **primera fecha después del periodo**: dms = _dateRe.allMatches(line, pm.end).toList(); toma dm = dms.first → dia/mesNum/anioDate. Construye echaPago = '--' (formato ISO yyyy-MM-dd).
3. Divide contexto:
   - efore = line.substring(0, pm.start).trim() (izquierda: nombre empleador + posiblemente Total Ganado)
   - fter = line.substring(dm.end).trim() (derecha: resto de columnas numéricas)
   Requiere efore no vacío.
4. Separa efore por espacios: ntes = before.split(RegExp(r'\s+'))
   - Si último token es **numérico puro** (_numTokenRe.hasMatch(antes.last)): 	otalGanado = num(antes.last), employer = antes.sublist(0, antes.length-1).join(' ') (el nombre del empleador puede tener espacios; lo que queda a izquierda del último número es el empleador). 
   - Si no: employer = before, 	otalGanado = 0.0 (caso Cobro de Comisión donde "Total Ganado" puede venir vacío).
5. Extrae **todos los números** de fter con _numRe.allMatches(after) → lista 
ums convertidos con 
um() (double).
6. Mapea columnas según cantidad:
   - Si 
ums.length >= 8: [dias, cotizacion, voluntario, beneficioSocial, comision, totalAportes, valorCuota, nroCuotas] = nums[0]..nums[7] (orden típico: Días trabajados, Cotización mensual, Aporte voluntario, Beneficio social, Comisión, Total aportes, Valor cuota, Total nº cuotas)
   - Si 
ums.length == 7: **caso "Cobro de comisión"** (columna "Días trabajados" vacía). Asigna: cotizacion = nums[0], voluntario=nums[1], beneficioSocial=nums[2], comision=nums[3], totalAportes=nums[4], valorCuota=nums[5], nroCuotas=nums[6], dias = 0.
   - Else: retorna 
ull (fila incompleta/no reconocible).
7. Retorna ParsedPayment con 	ipoMovimiento = isCommission(line) ? 'COMISION' : 'APORTE_LABORAL', campos mapeados y echaPago ISO.

> Nota: porteAfp y liquidoPagable **no se extraen directamente** de las columnas numéricas en este método tabular (método B). Se calculan después en capa de vista (ver 5.10).

### 5.9 Método principal parse(String text)

static ParsedResult parse(String text) (líneas ~470+ en archivo):

- lines = _normalizeLines(text)
- segurado = _extractAsegurado(lines)
- Busca **secciones de movimientos**: identifica bloque desde línea que contiene periodo (_lineHasPeriod) hacia adelante, agrupando hasta encontrar siguiente "resumen/totales" u otro patrón? (el código continúa construyendo lista de movimientos recorriendo líneas y aplicando split/parse). 
- Construye movimientos = <ParsedPayment>[]
- Recorre líneas buscando filas: para cada candidato usa _splitMovementRows sobre sección relevante y luego prueba _parseMovementLine primero (formato tabular estricto). Si no parsea, prueba _parseBlock (fallback por etiquetas). Solo añade si resultado no nulo.
- Retorna ParsedResult(asegurado: asegurado, movimientos: movimientos)

(El resto del método completa el recorrido; la lógica esencial es: normalizar → extraer asegurado → detectar filas con periodo/fecha → reconstruir fila con split → parsear por columnas (B) con fallback por etiquetas (A) → coleccionar movimientos.)

### 5.10 Interpretación en capa de aplicación (ProcesarView)

Una vez obtenido ParsedResult:

`dart
final movimientos = resultado.movimientos
  .where((m) =>
      m.empleador.trim().toUpperCase() == RegistroExtraido.empleadorEmap)
  .toList();

for (final movimiento in movimientos) {
  final aportesAfp = movimiento.totalGanado * 0.1271;  // 12,71%
  final cotizacionPdf = movimiento.cotizacionMensual;
  final integra = cotizacionPdf <= 0 ||
      (cotizacionPdf - movimiento.totalGanado * 0.10).abs() <= 0.5;
  nuevos.add(
    RegistroExtraido(
      ...
      totalGanado: movimiento.totalGanado,
      aportesAfp: aportesAfp,                        // calculado (no del PDF)
      liquidoPagable: movimiento.totalGanado - aportesAfp,  // calculado
      diasTrabajados: movimiento.diasTrabajados,
      requiereRevision: movimiento.requiereRevision || !integra,
    ),
  );
}
`

**Notas clave sobre reconocimiento de tablas:**
- **Sin posiciones fijas**: se basa en encabezados/etiquetas (Nombres y Apellidos, CUA, Periodo, etc.) y en presencia de patrones (Mes-Año, dd/MM/yyyy, números con formato latino).
- **Reconstrucción de filas partidas**: _splitMovementRows consolida líneas discontinuas en una fila lógica (clave para PDFs con saltos de línea).
- **Doble estrategia de parseo**: (B) parseo estructurado por columnas (empleador | totalGanado | periodo | fecha | días | cotización | voluntario | beneficio | comisión | total aportes | valor cuota | nº cuotas) — prioriza formato tabular real. (A) fallback por palabras clave.
- **Manejo de caso especial "Cobro de comisión"**: cuando 
ums.length == 7, se omite columna "Días trabajados" (vacía) y se asigna resto correctamente; 	ipoMovimiento = COMISION.
- **Detección de empleador**: heurística por líneas en MAYÚSCULAS/acentos sin periodo (evita confundir con otros textos).
- **Filtrado de ruido**: excluye líneas con "Total ganado" sin periodo y encabezados "empleador / tipo de movimiento".

## 6. FLUJO DE DATOS END-TO-END (RESUMEN)

`
PDF (.pdf)
  ↓ (pdfrx: PdfDocument.openFile + page.loadText())
Texto completo (String)
  ↓ (PdfParser._normalizeLines)
Líneas normalizadas (List<String>)
  ↓ (PdfParser._extractAsegurado)
Datos asegurado (Map: ci,nombres,apellidos,cua,...)
  ↓ (PdfParser._splitMovementRows + _parseMovementLine/_parseBlock)
ParsedPayment[] (movimientos: empleador, periodo, fechas, montos, días, tipo)
  ↓ (ProcesarView: filtra empleador == 'ENTIDAD MUNICIPAL DE ASEO POTOSI')
Movimientos filtrados
  ↓ (ProcesarView: calcula aportesAfp=totalGanado*0.1271, integra, requiereRevision)
RegistroExtraido[] (modelo de exportación)
  ↓ (HistorialService: guardar/cargar JSON local)
Historial persistido
  ↓ (ExportService._buildExcel + _agregarLogos + archive/excel)
XLSX (.xlsx) escrito vía FilePicker.saveFile
`

## 7. CONFIGURACIÓN, RECURSOS Y OTROS DETALLES

- **Tema**: AppTheme.light() (lib/app/theme.dart). Define paleta/estilos usados en UI.
- **Icono ventana**: ssets/logos/app_icon.ico (solo Windows) en main.dart:17.
- **Persistencia historial**: HistorialService gestiona carga/guardado de lista de RegistroExtraido (JSON). Ubicación gestionada por servicio (ruta local del SO). No se detalla ruta exacta aquí para no asumir implementación interna no leída, pero se usa en vista.
- **Exportación con logos**: ExportService._agregarLogos modifica el XLSX (paquete ZIP OOXML) usando rchive para incrustar imágenes de ssets/logos/ en el libro (ver export_service.dart referencias a Archive/ArchiveFile).
- **Cálculo de resúmenes**: ExportService.calcularResumenAportes(List<RegistroExtraido>) retorna estructura para mostrar totales/resúmenes anuales/certificado en UI (usado en ProcesarView.build para cabecera/resultados).
- **Filtrado estricto por empleador**: Solo registros con empleador.trim().toUpperCase() == 'ENTIDAD MUNICIPAL DE ASEO POTOSI' pasan a exportación/listado (ProcesarView). Esto es un filtro de negocio explícito.

## 8. REFERENCIAS A ARCHIVOS (ruta:líneas)

| Componente | Ruta | Líneas relevantes |
|---|---|---|
| Entrada | lib/main.dart | 1-23 |
| App | lib/app/app.dart | 1-18 |
| Tema | lib/app/theme.dart | (definición completa) |
| Modelo | lib/models/registro_extraido.dart | 1-85+ |
| Servicio PDF | lib/services/pdf_processing_service.dart | 1-35 |
| Exportación | lib/services/export_service.dart | 1-757 |
| Parser | lib/utils/pdf_parser.dart | 1-357 |
| Vista principal | lib/views/procesar/procesar_view.dart | 1-~400+ |
| Configuración | pubspec.yaml | 1-40 |

## 9. CONCLUSIÓN

El sistema EMAP funciona por **extracción de texto plano (pdfrx/Pdfium)** + **análisis no posicional por regex/heurísticas (PdfParser)** para reconstruir filas tabulares de movimientos (con split por líneas partidas y doble estrategia de parseo). Los datos del asegurado se extraen por etiquetas. Los cálculos de aportes AFP (12.71%) y líquido pagable se realizan en capa de aplicación. El filtrado por empleador es explícito. La exportación genera XLSX con estilos y logos usando excel + rchive.

Este informe describe **todo el funcionamiento, división, librerías y reconocimiento de tablas, sin excepciones y sin modificar el código**.

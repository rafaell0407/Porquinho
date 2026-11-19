import '../../../core/domain/calendar_date.dart';
import 'import_models.dart';

/// O que já existe no servidor e importa para a importação: categorias
/// (associação por nome), lançamentos (duplicidades, colisão de séries),
/// modelos ativos (colisão de séries) e arquivos já importados.
class ExistingCategory {
  const ExistingCategory({
    required this.id,
    required this.kind,
    required this.name,
    required this.active,
  });

  final String id;
  final CategoryKind kind;
  final String name;
  final bool active;
}

class ExistingSubcategory {
  const ExistingSubcategory({
    required this.id,
    required this.categoryId,
    required this.name,
    required this.active,
  });

  final String id;
  final String categoryId;
  final String name;
  final bool active;
}

class ExistingEntry {
  const ExistingEntry({
    required this.id,
    required this.kind,
    required this.date,
    required this.amount,
    required this.cancelled,
    this.description,
    this.categoryId,
    this.templateId,
  });

  final String id;
  final RowKind kind;

  /// Competência (receita pendente: data programada).
  final CalendarDate date;
  final BigInt? amount;
  final bool cancelled;
  final String? description;
  final String? categoryId;
  final String? templateId;
}

class ExistingTemplate {
  const ExistingTemplate({
    required this.id,
    required this.kind,
    required this.active,
    this.description,
    this.categoryId,
    this.amount,
  });

  final String id;
  final RowKind kind;
  final bool active;
  final String? description;
  final String? categoryId;
  final BigInt? amount;
}

/// Importação anterior não desfeita, com o mesmo arquivo (hash).
class PreviousImport {
  const PreviousImport({
    required this.batchId,
    required this.fileName,
    required this.fileSha256,
    required this.createdAt,
  });

  final String batchId;
  final String fileName;
  final String fileSha256;
  final DateTime createdAt;
}

class ExistingData {
  const ExistingData({
    this.categories = const [],
    this.subcategories = const [],
    this.entries = const [],
    this.templates = const [],
    this.imports = const [],
  });

  final List<ExistingCategory> categories;
  final List<ExistingSubcategory> subcategories;
  final List<ExistingEntry> entries;
  final List<ExistingTemplate> templates;
  final List<PreviousImport> imports;
}

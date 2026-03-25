
import 'package:equatable/equatable.dart';

class Company extends Equatable {
  final String id;
  final String nome;
  final String cnpj;
  final String regime;
  final String uf;

  const Company({required this.id, required this.nome, required this.cnpj, required this.regime, required this.uf});

  factory Company.fromJson(Map<String, dynamic> j) => Company(
    id: j['id'], nome: j['nome'], cnpj: j['cnpj'], regime: j['regime'], uf: j['uf'],
  );

  @override
  List<Object?> get props => [id, nome, cnpj, regime, uf];
}

class Obligation extends Equatable {
  final String id;
  final String nome;
  final String esfera;
  final String descricao;

  const Obligation({required this.id, required this.nome, required this.esfera, required this.descricao});

  factory Obligation.fromJson(Map<String, dynamic> j) => Obligation(
    id: j['id'], nome: j['nome'], esfera: j['esfera'], descricao: j['descricao'],
  );

  @override
  List<Object?> get props => [id, nome, esfera, descricao];
}

class DueDate extends Equatable {
  final String id;
  final String companyId;
  final String obligationId;
  final String competencia;
  final DateTime vencimento;
  final String status;

  const DueDate({required this.id, required this.companyId, required this.obligationId, required this.competencia, required this.vencimento, required this.status});

  DueDate copyWith({String? status}) => DueDate(
    id: id, companyId: companyId, obligationId: obligationId, competencia: competencia, vencimento: vencimento, status: status ?? this.status,
  );

  factory DueDate.fromJson(Map<String, dynamic> j) => DueDate(
    id: j['id'],
    companyId: j['companyId'],
    obligationId: j['obligationId'],
    competencia: j['competencia'],
    vencimento: DateTime.parse(j['vencimento']),
    status: j['status'],
  );

  @override
  List<Object?> get props => [id, companyId, obligationId, competencia, vencimento, status];
}

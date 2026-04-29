# Contador+ (v0.3)

Aplicativo Flutter para gestão de obrigações e vencimentos, com recursos de IA e integrações externas.

## Principais recursos
- Consulta e organização de obrigações por período.
- Integração com OpenAI via `dio` usando variáveis de ambiente.
- Exportação de vencimentos em `.ics` para compartilhamento em calendário.
- Módulo de timeline da Reforma Tributária integrado ao app.

## Requisitos
- Flutter SDK instalado e configurado.
- Arquivo `.env` com as chaves necessárias.

## Configuração e execução
1. Copie o arquivo de exemplo:
   - `cp .env.example .env`
2. Defina pelo menos:
   - `OPENAI_API_KEY`
3. Instale dependências:
   - `flutter pub get`
4. Caso a pasta `android/` não exista:
   - `flutter create .`
5. Execute o app:
   - `flutter run`

## Estrutura de documentação
- `README.md`: visão geral do projeto e setup.
- `server/README_SERVER.md`: instruções do proxy/backend.

## Observações
- Ajustes de modelo/endpoint da OpenAI podem ser feitos no `.env`.
- Documentações antigas e redundantes foram consolidadas neste README.

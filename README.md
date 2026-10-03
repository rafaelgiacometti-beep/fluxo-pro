# Medical R.G.

PWA para gestão comercial de produtos de venda autorizada. Interface em português, valores em euros e sincronização entre dispositivos através da mesma conta Supabase. O frontend pode ser alojado no GitHub Pages sem dependências ou compilação.

## Incluído

- Produtos, referências, custos, preços e stock mínimo.
- Clientes e histórico comercial.
- Encomendas a fornecedores, data prevista e receções parciais.
- Vendas com reserva de unidades; pré-encomendas opcionais quando falta stock.
- Pagamentos parciais de clientes e pagamentos a fornecedores, registados separadamente.
- Entrega com saída de stock e acompanhamento um mês de calendário depois.
- Agenda com aviso antecipado configurável (5 dias por defeito).
- Ajustes de inventário com motivo e histórico de movimentos.
- Exportação JSON para arquivo.
- Conta online e modo de demonstração com dados fictícios.
- Manifesto, ícones e service worker para instalação no telemóvel.

## Começar

Siga [GUIA-INSTALACAO.md](GUIA-INSTALACAO.md). Para experimentar antes de configurar, sirva a pasta `docs` com um servidor HTTP e escolha **Experimentar demonstração**. Abrir `index.html` diretamente por `file://` não funciona, porque os módulos e o service worker requerem HTTP/HTTPS.

## Estrutura

```text
docs/                       Aplicação publicável no GitHub Pages
supabase/schema.sql         Tabelas, políticas e funções transacionais
tests/                      Verificações de stock, pagamentos, datas e API
.github/workflows/pages.yml Publicação com GitHub Actions
GUIA-INSTALACAO.md          Configuração e utilização
```

## Verificação

```bash
npm run check
npm test
```

Não é necessário `npm install`; os testes usam o Node.js 22 ou superior e bibliotecas nativas. O modo online usa os mesmos campos do modo de demonstração, mas as regras são novamente verificadas no PostgreSQL. Todas as alterações de uma conta são serializadas na base de dados. O identificador de pedido evita repetições após uma falha de ligação.

## Limites desta versão

- Cada conta possui os seus próprios registos. Para os mesmos dados em vários dispositivos, entre com a mesma conta. Não há partilha entre utilizadores diferentes.
- Cada venda/encomenda contém um produto. Para vários produtos, crie registos separados.
- O modo online precisa de internet. O service worker guarda apenas os ficheiros da aplicação; não guarda os dados privados nem coloca alterações numa fila offline.
- Os alertas são mostrados ao abrir a aplicação; não há notificações com a aplicação fechada nem mensagens automáticas a clientes.
- A aplicação regista pagamentos já realizados; não cobra dinheiro e não emite faturas fiscais.
- Não há devoluções/reembolsos nesta versão. Registos com pagamento, receção ou entrega não podem ser cancelados pela interface.
- A exportação JSON serve para arquivo; não existe importação automática. Para recuperação completa, use os backups da base de dados.
- Não há instalação automática da base de dados. É necessário executar o SQL e criar a conta no Supabase.

## Segurança

As chaves publicáveis podem estar no frontend. Nunca coloque chaves `service_role`, `sb_secret_...`, palavra-passe da base de dados ou tokens pessoais no repositório. A autorização vem de Supabase Auth e das políticas de acesso por conta. As tabelas permitem apenas leitura direta das próprias linhas; alterações só através da função validada `fluxo_action`. A sessão é guardada no navegador; termine sessão em dispositivos partilhados.

Não existem dados reais de clientes no projeto ou nos exemplos.

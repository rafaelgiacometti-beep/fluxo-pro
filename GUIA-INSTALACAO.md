# Instalar o Fluxo Pro

## 1. Preparar a base de dados

1. Abra [Supabase](https://supabase.com/) e crie um projeto. Escolha uma região europeia se os seus dados forem de clientes em Portugal.
2. Abra **SQL Editor → New query**.
3. Copie o conteúdo completo de `supabase/schema.sql`, cole no editor e execute **Run**. Faça isto uma vez num projeto novo; o ficheiro não é uma migração para uma base já existente.
4. Em **Authentication → Users**, escolha **Add user / Create new user**. Crie o seu email e palavra-passe e confirme o utilizador. Não partilhe a palavra-passe aqui no chat ou no GitHub.
5. Para usar apenas a sua conta, desative o registo público em **Authentication → Providers → Email → Allow new users to sign up**, se estiver ativo.
6. Em **Project Settings → Data API / API Keys**, obtenha a **Project URL** e a chave **publishable** (ou a chave antiga **anon**). Não use `service_role` nem chaves secretas.

O frontend usa a API REST; confirme que a Data API está ativa e o esquema `public` está exposto. As tabelas começam vazias. Os exemplos só existem no modo demonstração.

## 2. Publicar no GitHub

1. Crie um repositório chamado `fluxo-pro` na sua conta GitHub, com o ramo principal `main`. Não inclua dados de clientes.
2. Envie o conteúdo desta pasta para o repositório, mantendo a estrutura. A pasta `docs` deve estar diretamente na raiz do repositório.
3. A forma mais simples de publicar é **Settings → Pages → Build and deployment → Source: Deploy from a branch → Branch: main → Folder: /docs → Save**.
4. Aguarde a publicação. O endereço será `https://SEU-UTILIZADOR.github.io/fluxo-pro/`.

Também existe o ficheiro `.github/workflows/pages.yml` para publicação com GitHub Actions e execução dos testes. Para usar esse método, escolha **Source: GitHub Actions** em vez de **Deploy from a branch** e execute **Actions → Publicar Fluxo Pro → Run workflow**. Use apenas um dos métodos. Dependendo do plano GitHub, Pages num repositório privado pode não estar disponível; o código pode ser público sem expor os dados privados, que ficam no Supabase.

### Ligação online

Ao abrir o endereço publicado, escolha **Configurar ligação online** e indique a Project URL e a chave publicável. Entre com a conta criada no passo 1. Repita a configuração no telemóvel.

Para não repetir a configuração em cada dispositivo, pode editar `docs/config.js` no repositório:

```js
window.FLUXO_CONFIG = {
  supabaseUrl: 'https://SEU-PROJETO.supabase.co',
  publishableKey: 'SUA-CHAVE-PUBLICAVEL'
};
```

URL e chave publicável não são uma palavra-passe; os registos continuam protegidos pela conta e pelas políticas. Nunca coloque uma chave secreta neste ficheiro. Se uma ligação guardada no dispositivo estiver incorreta, use **Alterar ligação** no ecrã de entrada.

## 3. Instalar como aplicação

**iPhone:** abra o endereço no Safari → Partilhar → Adicionar ao ecrã principal → Adicionar.

**Android:** abra no Chrome → menu → Instalar aplicação / Adicionar ao ecrã principal.

**Computador:** use a opção de instalar no Chrome ou Edge. Quando o navegador disponibilizar a instalação, a opção também aparece em Definições.

O endereço deve ser HTTPS. A instalação não muda onde os dados ficam guardados.

## 4. Primeiro ciclo de utilização

1. Em **Stock**, crie o produto com preço, custo, stock inicial e stock mínimo.
2. Em **Clientes**, crie o cliente.
3. Em **Encomendas**, registe fornecedor, quantidade, custo e chegada prevista.
4. Ao receber mercadoria, abra a encomenda → **Registar chegada**. Se chegaram apenas algumas unidades, registe só essas; o restante continua a chegar.
5. Em **Vendas**, registe cliente, produto e quantidade. Se ainda não houver stock, assinale **Pré-encomenda**.
6. Abra a venda → **Receber pagamento** e registe o valor pago. Pode registar vários pagamentos até completar o total.
7. Depois de entregar ao cliente, escolha **Confirmar entrega**. Só é possível se houver stock físico suficiente.
8. A agenda mostra a próxima data um mês depois. Exemplo: entrega em 03/10 → acompanhamento em 03/11. Entrega em 31/01 → 28/02 (ou 29/02 em ano bissexto).
9. Após acompanhar o cliente, marque **Concluir**. Use **Nova venda** para abrir outro pedido com cliente e produto preenchidos; o pedido só é criado quando guardar o formulário.

**Pagamentos a fornecedores:** abra a encomenda → **Pagar fornecedor**. Estes pagamentos não são confundidos com dinheiro recebido de clientes.

**Disponível:** stock físico menos pedidos reservados. Pré-encomendas podem deixar este número negativo; significa unidades em falta, não mercadoria negativa no armazém.

## 5. Usar no computador e no telemóvel

Entre com a mesma conta nos dois dispositivos. Os registos são consultados ao abrir a aplicação, ao voltar à janela, ao clicar em atualizar e de 20 em 20 segundos quando estiver aberta. Os formulários abertos não são substituídos durante essa atualização; o servidor valida novamente o stock e o saldo ao guardar.

Com internet desligada, a aplicação pode abrir a estrutura já instalada, mas os dados online não são consultados nem alterados. O modo demonstração funciona localmente e não sincroniza.

## 6. Cópias e manutenção

- Em **Definições → Exportar registos**, descarregue uma cópia JSON. Guarde-a num local privado; pode conter contactos comerciais. Não publique esta cópia no GitHub.
- A exportação não inclui credenciais e não pode ser importada automaticamente pela interface. Configure os backups disponíveis no seu projeto Supabase e verifique as opções de recuperação do seu plano.
- Para atualizar o PWA, envie os novos ficheiros para o GitHub e aumente a versão `CACHE` em `docs/sw.js`. Depois da publicação, feche todas as janelas da aplicação e volte a abrir.
- Produtos e clientes podem ser arquivados em **Editar**; o histórico é mantido.
- Ajustes de stock exigem motivo. Não podem retirar unidades reservadas.

## Problemas comuns

| Situação | O que verificar |
| --- | --- |
| Email ou palavra-passe incorretos | Conta criada e confirmada em Authentication → Users. |
| Erro ao consultar a base | SQL completo executado, API ativa, URL e chave publicável do mesmo projeto. |
| Stock insuficiente ao guardar venda | Receber mercadoria primeiro ou assinalar Pré-encomenda. |
| Não pode entregar | É necessário stock físico suficiente; confirme a receção em Encomendas. |
| Pagamento superior ao saldo | Registe apenas o valor em falta; atualize para ver pagamentos de outro dispositivo. |
| Não consegue cancelar | Não é permitido depois de pagamentos, receções ou entrega. |
| Computador e telemóvel têm dados diferentes | Confirme mesma Project URL, mesma conta e que nenhum está em demonstração. |
| A aplicação não abre ao clicar em index.html | Use o endereço publicado ou um servidor HTTP; não abra por file://. |

Documentação: [GitHub Pages](https://docs.github.com/en/pages/getting-started-with-github-pages/creating-a-github-pages-site), [Supabase Auth](https://supabase.com/docs/guides/auth), [Row Level Security](https://supabase.com/docs/guides/database/postgres/row-level-security).

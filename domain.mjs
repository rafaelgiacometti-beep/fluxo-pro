export const today = () => { const d = new Date(); return `${d.getFullYear()}-${String(d.getMonth()+1).padStart(2,'0')}-${String(d.getDate()).padStart(2,'0')}`; };
export const money = n => new Intl.NumberFormat('pt-PT', {style:'currency',currency:'EUR'}).format((n || 0)/100);
export function cents(value) {
  const s = String(value).trim().replace(',', '.');
  if (!/^\d+(\.\d{1,2})?$/.test(s)) throw Error('Indique um valor válido, com até duas casas decimais.');
  const [a,b=''] = s.split('.'); const n=Number(a)*100+Number(b.padEnd(2,'0'));
  if (!Number.isSafeInteger(n) || n>100000000) throw Error('Valor demasiado elevado.');
  return n;
}
export function addMonth(date) {
  const [y,m,d]=date.split('-').map(Number); const target=new Date(y,m,1,12);
  const end=new Date(target.getFullYear(),target.getMonth()+1,0).getDate();
  return `${target.getFullYear()}-${String(target.getMonth()+1).padStart(2,'0')}-${String(Math.min(d,end)).padStart(2,'0')}`;
}
export function daysBetween(a,b) {return Math.round((Date.parse(b+'T12:00:00Z')-Date.parse(a+'T12:00:00Z'))/86400000);}
export function stockFor(s,id) {
  const physical=s.movements.filter(x=>x.product_id===id).reduce((n,x)=>n+x.quantity,0);
  const reserved=s.sales.filter(x=>x.product_id===id&&x.status==='pending').reduce((n,x)=>n+x.quantity,0);
  return {physical,reserved,available:physical-reserved};
}
export function paidFor(s,kind,id) {return s.payments.filter(x=>x.kind===kind&&x.record_id===id).reduce((n,x)=>n+x.amount_cents,0);}
export function totalFor(row) {return row.quantity*row.unit_cents;}
export function dueFor(s,kind,row) {return totalFor(row)-paidFor(s,kind,row.id);}
export function emptyState() {return {products:[],customers:[],purchases:[],sales:[],payments:[],movements:[],settings:{name:'Medical R.G.',reminder_days:5},requests:[]};}
const integer=(n,min=1)=>{n=Number(n);if(!Number.isInteger(n)||n<min||n>100000000)throw Error('Quantidade ou valor inválido.');return n;};
const label=(v)=>{v=String(v||'').trim();if(!v||v.length>160)throw Error('Preencha um nome com até 160 caracteres.');return v;};
const date=(v)=>{if(!/^\d{4}-\d{2}-\d{2}$/.test(v||'')||Number.isNaN(Date.parse(v+'T12:00:00Z'))||new Date(v+'T12:00:00Z').toISOString().slice(0,10)!==v)throw Error('Data inválida.');return v;};
const find=(rows,id)=>{const r=rows.find(x=>x.id===id);if(!r)throw Error('Registo não encontrado.');return r;};
export function applyCommand(input,kind,p,{id=crypto.randomUUID(),now=today()}={}) {
  const s=structuredClone(input);
  if(s.requests.includes(id))return s;
  const newId=()=>crypto.randomUUID();
  const movement=(product_id,quantity,note)=>s.movements.push({id:newId(),product_id,quantity,note,created_at:now});
  switch(kind) {
    case 'product': {
      const r={name:label(p.name),sku:String(p.sku||'').trim().slice(0,60),price_cents:integer(p.price_cents,0),cost_cents:integer(p.cost_cents,0),minimum:integer(p.minimum,0),lead_days:integer(p.lead_days,0),active:p.active!==false};
      if(r.sku&&s.products.some(x=>x.sku===r.sku&&x.id!==p.id))throw Error('Esta referência já existe.');
      if(p.id)Object.assign(find(s.products,p.id),r);
      else {const row={id:newId(),...r};s.products.push(row);const initial=integer(p.initial||0,0);if(initial)movement(row.id,initial,'Stock inicial');}break;
    }
    case 'customer': {
      const r={name:label(p.name),phone:String(p.phone||'').slice(0,60),note:String(p.note||'').slice(0,1000),active:p.active!==false};
      if(p.id)Object.assign(find(s.customers,p.id),r);else s.customers.push({id:newId(),...r});break;
    }
    case 'purchase': {
      const product=find(s.products,p.product_id);if(!product.active)throw Error('Produto arquivado.');
      const ordered_at=date(p.ordered_at),expected_at=date(p.expected_at);if(expected_at<ordered_at)throw Error('A chegada prevista deve ser após a encomenda.');
      s.purchases.push({id:newId(),product_id:p.product_id,supplier:label(p.supplier),quantity:integer(p.quantity),unit_cents:integer(p.unit_cents,0),received:0,ordered_at,expected_at,status:'open',note:String(p.note||'').slice(0,1000)});break;
    }
    case 'receive': {
      const r=find(s.purchases,p.id),q=integer(p.quantity);if(r.status!=='open')throw Error('Esta encomenda já está encerrada.');
      if(q>r.quantity-r.received)throw Error('Quantidade superior ao que falta receber.');
      r.received+=q;if(r.received===r.quantity)r.status='received';movement(r.product_id,q,`Receção: ${r.supplier}`);break;
    }
    case 'sale': {
      const product=find(s.products,p.product_id),customer=find(s.customers,p.customer_id);if(!product.active||!customer.active)throw Error('Produto ou cliente arquivado.');
      const quantity=integer(p.quantity);if(stockFor(s,p.product_id).available<quantity&&p.allow_backorder!==true)throw Error('Stock disponível insuficiente. Assinale pré-encomenda para aguardar a chegada.');
      s.sales.push({id:newId(),product_id:p.product_id,customer_id:p.customer_id,quantity,unit_cents:integer(p.unit_cents,0),ordered_at:date(p.ordered_at),status:'pending',delivered_at:null,followup_at:null,followup_done:false,note:String(p.note||'').slice(0,1000)});break;
    }
    case 'deliver': {
      const r=find(s.sales,p.id);if(r.status!=='pending')throw Error('Esta venda já está encerrada.');
      if(stockFor(s,r.product_id).physical<r.quantity)throw Error('Stock insuficiente para entregar.');
      const d=date(p.delivered_at);if(d<r.ordered_at||d>now)throw Error('A entrega deve ser entre a encomenda e hoje.');
      r.status='delivered';r.delivered_at=d;r.followup_at=addMonth(d);movement(r.product_id,-r.quantity,'Entrega ao cliente');break;
    }
    case 'payment': {
      if(!['sale','purchase'].includes(p.kind))throw Error('Tipo de pagamento inválido.');
      const r=find(s[p.kind==='sale'?'sales':'purchases'],p.record_id);if(r.status==='cancelled')throw Error('Registo cancelado.');
      const amount=integer(p.amount_cents);if(amount>dueFor(s,p.kind,r))throw Error('O pagamento excede o valor em falta.');
      const paid_at=date(p.paid_at);if(paid_at>now)throw Error('O pagamento não pode ser futuro.');
      s.payments.push({id:newId(),kind:p.kind,record_id:p.record_id,amount_cents:amount,paid_at,method:label(p.method)});break;
    }
    case 'cancel': {
      if(!['sale','purchase'].includes(p.kind))throw Error('Tipo inválido.');
      const r=find(s[p.kind==='sale'?'sales':'purchases'],p.id);
      if(paidFor(s,p.kind,r.id)>0||r.status==='delivered'||(r.received||0)>0)throw Error('Só pode cancelar registos sem pagamentos, receções ou entregas.');
      r.status='cancelled';break;
    }
    case 'adjust': {
      const r=find(s.products,p.product_id),q=Number(p.quantity);if(!Number.isInteger(q)||q===0||Math.abs(q)>100000000)throw Error('Ajuste inválido.');
      if(q<0&&stockFor(s,r.id).available+q<0)throw Error('O ajuste compromete stock reservado.');movement(r.id,q,label(p.note));break;
    }
    case 'followup': {const r=find(s.sales,p.id);if(r.status!=='delivered')throw Error('Venda ainda não entregue.');r.followup_done=p.done===true;break;}
    case 'settings': {s.settings={name:label(p.name),reminder_days:integer(p.reminder_days,0)};if(s.settings.reminder_days>30)throw Error('Escolha entre 0 e 30 dias.');break;}
    default:throw Error('Ação desconhecida.');
  }
  s.requests.push(id);return s;
}
export function demoState() {
  let s=emptyState();const run=(k,p)=>s=applyCommand(s,k,p);
  run('product',{name:'Caderno A5',sku:'CAD-A5',price_cents:850,cost_cents:350,minimum:5,lead_days:30,initial:24});
  run('product',{name:'Garrafa reutilizável',sku:'GAR-600',price_cents:1800,cost_cents:800,minimum:4,lead_days:30,initial:8});
  run('product',{name:'Estojo de tecido',sku:'EST-01',price_cents:1200,cost_cents:500,minimum:6,lead_days:15,initial:3});
  run('customer',{name:'Cliente de exemplo',phone:'',note:'Dados fictícios para experimentar.'});
  run('customer',{name:'Segundo cliente',phone:'',note:''});
  const d=new Date();d.setDate(d.getDate()-32);const old=`${d.getFullYear()}-${String(d.getMonth()+1).padStart(2,'0')}-${String(d.getDate()).padStart(2,'0')}`;
  run('sale',{product_id:s.products[0].id,customer_id:s.customers[0].id,quantity:2,unit_cents:850,ordered_at:old});
  run('deliver',{id:s.sales[0].id,delivered_at:old});
  run('payment',{kind:'sale',record_id:s.sales[0].id,amount_cents:1000,paid_at:old,method:'Transferência'});
  run('sale',{product_id:s.products[1].id,customer_id:s.customers[1].id,quantity:1,unit_cents:1800,ordered_at:today()});
  run('purchase',{product_id:s.products[2].id,supplier:'Fornecedor de exemplo',quantity:12,unit_cents:500,ordered_at:today(),expected_at:addMonth(today())});
  return s;
}

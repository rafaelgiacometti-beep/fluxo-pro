import {demoState,applyCommand} from './domain.mjs';
export class DemoAPI {
  constructor(){this.mode='demo';try{this.state=JSON.parse(localStorage.getItem('fluxo-demo-v1'))||demoState();}catch{this.state=demoState();}}
  async snapshot(){return structuredClone(this.state);}
  async command(kind,payload,request_id=crypto.randomUUID()){const next=applyCommand(this.state,kind,payload,{id:request_id});localStorage.setItem('fluxo-demo-v1',JSON.stringify(next));this.state=next;return this.snapshot();}
  reset(){this.state=demoState();localStorage.setItem('fluxo-demo-v1',JSON.stringify(this.state));}
}
export class CloudAPI {
  constructor(config){this.mode='cloud';this.url=config.supabaseUrl.replace(/\/$/,'');this.key=config.publishableKey;this.storageKey=`fluxo-session:${this.url}`;this.refreshing=null;try{this.session=JSON.parse(localStorage.getItem(this.storageKey));}catch{this.session=null;}}
  save(session){this.session=session;if(session)localStorage.setItem(this.storageKey,JSON.stringify(session));else localStorage.removeItem(this.storageKey);}
  async request(path,{method='GET',body,token,retry=true}={}) {
    const headers={apikey:this.key,'Content-Type':'application/json'};if(token)headers.Authorization=`Bearer ${token}`;
    let response;
    try{response=await fetch(this.url+path,{method,headers,body:body?JSON.stringify(body):undefined,cache:'no-store'});}catch{throw Error('Sem ligação. Os dados online não foram alterados. Volte a tentar quando tiver internet.');}
    const data=await response.json().catch(()=>null);
    if(response.status===401&&token&&retry&&this.session?.refresh_token){await this.refresh();return this.request(path,{method,body,token:this.session.access_token,retry:false});}
    if(!response.ok){const msg=data?.message||data?.msg||data?.error_description||'Não foi possível concluir a operação.';throw Error(msg==='Invalid login credentials'?'Email ou palavra-passe incorretos.':msg);}
    return data;
  }
  async login(email,password){const s=await this.request('/auth/v1/token?grant_type=password',{method:'POST',body:{email,password}});this.save(s);}
  async refresh(){if(!this.refreshing)this.refreshing=(async()=>{try{const s=await this.request('/auth/v1/token?grant_type=refresh_token',{method:'POST',body:{refresh_token:this.session.refresh_token},retry:false});this.save(s);}catch(e){this.save(null);throw Error('A sessão expirou. Entre novamente.');}finally{this.refreshing=null;}})();return this.refreshing;}
  async token(){if(!this.session)throw Error('Entre na sua conta.');if(this.session.expires_at&&this.session.expires_at*1000<Date.now()+60000)await this.refresh();return this.session.access_token;}
  async snapshot(){return this.request('/rest/v1/rpc/fluxo_snapshot',{method:'POST',body:{},token:await this.token()});}
  async command(kind,payload,request_id=crypto.randomUUID()){return this.request('/rest/v1/rpc/fluxo_action',{method:'POST',body:{a:{kind,payload,request_id}},token:await this.token()});}
  async logout(){try{if(this.session)await this.request('/auth/v1/logout',{method:'POST',token:this.session.access_token,retry:false});}catch{/* A saída local deve funcionar mesmo sem rede. */}finally{this.save(null);}}
}
export function loadConfig(){let config=window.FLUXO_CONFIG||{};try{config={...config,...JSON.parse(localStorage.getItem('fluxo-config-v1')||'{}')};}catch{}return config;}
export function validateConfig(url,key){
  let u;try{u=new URL(url);}catch{throw Error('URL do Supabase inválida.');}
  if(u.protocol!=='https:'||!u.hostname.endsWith('.supabase.co')||u.pathname!=='/'||u.search||u.hash)throw Error('Use a URL https://SEU-PROJETO.supabase.co.');
  if(!key||(!key.startsWith('sb_publishable_')&&!key.startsWith('eyJ')))throw Error('Use a chave publicável ou a antiga chave anon.');
  if(key.startsWith('eyJ')){try{const claim=JSON.parse(atob(key.split('.')[1].replace(/-/g,'+').replace(/_/g,'/')));if(claim.role!=='anon')throw Error();}catch{throw Error('Apenas a chave anon é permitida. Nunca use service_role.');}}
  return {supabaseUrl:u.origin,publishableKey:key};
}

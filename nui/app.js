const app = document.getElementById('app');
const seqEl = document.getElementById('sequence');
const inputEl = document.getElementById('input');
const padEl = document.getElementById('pad');
const attemptsEl = document.getElementById('attempts');
const timerEl = document.getElementById('timer');
const instructionEl = document.getElementById('instruction');

let state = { active:false, token:null, sequence:[], input:[], reveal:true, expiresAt:0, timer:null, revealTimer:null, attempts:3 };
const keys = ['W','A','S','D','Q','E'];

const post = (event, data={}) => fetch(`https://${GetParentResourceName()}/${event}`, {method:'POST', headers:{'Content-Type':'application/json'}, body:JSON.stringify(data)}).then(r=>r.json()).catch(()=>({}));
const esc = (v) => String(v ?? '').replace(/[&<>'"]/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;',"'":'&#39;','"':'&quot;'}[c]));

function render(){
  seqEl.innerHTML = state.sequence.map(k => `<div class="key">${state.reveal ? esc(k) : '•'}</div>`).join('');
  inputEl.innerHTML = state.sequence.map((_,i) => state.input[i] ? `<div class="key done">${esc(state.input[i])}</div>` : '<div class="key blank">•</div>').join('');
  padEl.innerHTML = keys.map(k => `<button data-key="${k}">${k}</button>`).join('');
  padEl.querySelectorAll('button').forEach(b => b.onclick = () => push(b.dataset.key));
  attemptsEl.textContent = `${state.attempts} attempt${state.attempts === 1 ? '' : 's'} left`;
}

function open(data){
  state = {active:true, token:data.token, sequence:(data.sequence||[]).map(String), input:[], reveal:true, expiresAt:Date.now()+Number(data.timeout||18000), timer:null, revealTimer:null, attempts:Number(data.attempts||3)};
  app.classList.remove('hidden'); instructionEl.textContent='Memorise the sequence.'; render();
  clearTimeout(state.revealTimer); clearInterval(state.timer);
  state.revealTimer = setTimeout(()=>{state.reveal=false;state.input=[];instructionEl.textContent='Repeat the sequence.';render();}, Number(data.revealMs||1600));
  state.timer = setInterval(()=>{const left=Math.max(0,state.expiresAt-Date.now());timerEl.textContent=(left/1000).toFixed(1);if(left<=0) submit();},100);
}

async function push(k){
  if(!state.active || state.reveal) return;
  const expected = state.sequence[state.input.length];
  state.input.push(k); render();
  if(k!==expected){
    const result=await submit();
    if(result?.attemptsLeft>0){
      setTimeout(()=>{state.reveal=true;state.input=[];instructionEl.textContent='Wrong sequence. Memorise it again.';render();clearTimeout(state.revealTimer);state.revealTimer=setTimeout(()=>{state.reveal=false;state.input=[];instructionEl.textContent='Repeat the sequence.';render();},1100);},120);
    }
    return;
  }
  if(state.input.length===state.sequence.length) await submit();
}

async function submit(){
  if(!state.active) return null;
  const result=await post('finish',{token:state.token,input:state.input});
  if(result?.success){close();return result;}
  if(result?.attemptsLeft>0){state.attempts=result.attemptsLeft;state.sequence=(result.sequence||state.sequence).map(String);state.input=[];return result;}
  close();return result;
}

function closeLocal(){
  clearTimeout(state.revealTimer);clearInterval(state.timer);app.classList.add('hidden');state={active:false,token:null,sequence:[],input:[],reveal:true,expiresAt:0,timer:null,revealTimer:null,attempts:3};
}
function close(){closeLocal();post('cancel');}

document.getElementById('cancel').onclick=close;
window.addEventListener('message',e=>{if(e.data?.action==='open')open(e.data.data||{});if(e.data?.action==='close')closeLocal();});
window.addEventListener('keydown',e=>{if(!state.active)return;if(e.key==='Escape'){close();return;}const k=e.key.toUpperCase();if(keys.includes(k))push(k);});

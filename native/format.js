// Формат schedule.json: те же функции, что в admin.html, чтобы файл сохранялся байт в байт так же
var data=null;
var DSHORT=["Пн","Вт","Ср","Чт","Пт","Сб"];
var DFULL=["Воскресенье","Понедельник","Вторник","Среда","Четверг","Пятница","Суббота"];
var MONS=["янв","фев","мар","апр","мая","июн","июл","авг","сен","окт","ноя","дек"];
var MONF=["января","февраля","марта","апреля","мая","июня","июля","августа","сентября","октября","ноября","декабря"];
function pd(s){var a=String(s).split("-");return new Date(+a[0],a[1]-1,+a[2]);}
function toMin(t){var a=String(t).split(":");return a[0]*60+ +a[1];}
function normTime(t){return t?String(t).replace(/^0(\d)/,"$1"):"";}
function dlabel(k){var d=pd(k);return DFULL[d.getDay()]+", "+d.getDate()+" "+MONF[d.getMonth()];}
var DATE_RE=/^\d{4}-\d\d-\d\d$/;
function asArr(v){return Array.isArray(v)?v:(v?[v]:[]);}
function addU(a,v){if(v&&a.indexOf(v)<0)a.push(v);}
function splitR(v){var out=[];asArr(v).forEach(function(x){String(x).split(/\s*,\s*/).forEach(function(y){y=y.trim();if(y)addU(out,y);});});return out;}
function clean(x){
  if(x._sw){var y={};for(var q in x)y[q]=x[q];y.lessons=x.alt.lessons;y.changes=x.alt.changes;y.alt={h:x.alt.h,lessons:x.lessons,changes:x.changes};y._sw=false;x=y;}
  function pick(o,ks){var r={};ks.forEach(function(k){if(o[k]!==undefined&&o[k]!==""&&o[k]!==null&&o[k]!==false)r[k]=o[k];});return r;}
  var out={updated:x.updated||0,anchor:x.anchor,anchorType:x.anchorType,start:x.start||undefined,end:x.end,bells:x.bells.map(function(b){return b[2]&&b[3]?[normTime(b[0]),normTime(b[1]),normTime(b[2]),normTime(b[3])]:[normTime(b[0]),normTime(b[1])];})};
  if(!out.start)delete out.start;
  out.lessons=x.lessons.map(function(l){return pick(l,["d","p","w","s","t","tch","r","from"]);})
    .sort(function(a,b){return a.d-b.d||a.p-b.p||(a.w>b.w?1:a.w<b.w?-1:0);});
  out.changes={};
  Object.keys(x.changes||{}).sort().forEach(function(k){
    var a=x.changes[k].map(function(c){return c.cancel?pick(c,["p","cancel","was"]):pick(c,["p","s","t","tch","r","was","ed"]);});
    if(a.length)out.changes[k]=a;
  });
  if(x.alt&&(x.alt.h||x.alt.lessons)){
    out.alt={};
    if(x.alt.h)out.alt.h=x.alt.h;
    if(x.alt.lessons){
      out.alt.lessons=x.alt.lessons.map(function(l){return pick(l,["d","p","w","s","t","tch","r","from"]);}).sort(function(a,b){return a.d-b.d||a.p-b.p||(a.w>b.w?1:a.w<b.w?-1:0);});
      var ac={};
      Object.keys(x.alt.changes||{}).sort().forEach(function(k){
        var a=x.alt.changes[k].map(function(c){return c.cancel?pick(c,["p","cancel","was"]):pick(c,["p","s","t","tch","r","was","ed"]);});
        if(a.length)ac[k]=a;
      });
      out.alt.changes=ac;
    }
  }
  // Справочник карточек пар: то, что админ создал сам (карточки из расписания добавляются автоматически)
  out.cards=(x.cards||[]).map(function(k){return {s:k.s,tch:k.tch||"",r:splitR(k.r)};})
    .sort(function(a,b){return a.s.localeCompare(b.s,"ru")||a.tch.localeCompare(b.tch,"ru");});
  out.session=x.session?{from:x.session.from,to:x.session.to,items:(x.session.items||[]).map(function(i){return pick(i,["date","time","kind","s","tch","r"]);})
    .sort(function(a,b){return a.date<b.date?-1:a.date>b.date?1:toMin(a.time)-toMin(b.time);})}:null;
  return out;
}
function ser(o){
  var J=JSON.stringify, L=["{"], ks=Object.keys(o);
  function arr(ind,name,v,c){L.push(ind+J(name)+": [");v.forEach(function(x,j){L.push(ind+"  "+J(x)+(j<v.length-1?",":""));});L.push(ind+"]"+c);}
  ks.forEach(function(k,i){
    var v=o[k], c=i<ks.length-1?",":"";
    if(Array.isArray(v)&&v.length)arr("  ",k,v,c);
    else if(v&&typeof v==="object"&&!Array.isArray(v)&&Object.keys(v).length){
      L.push("  "+J(k)+": {"); var k2=Object.keys(v);
      k2.forEach(function(kk,j){var vv=v[kk],c2=j<k2.length-1?",":"";
        if(Array.isArray(vv)&&vv.length&&typeof vv[0]==="object")arr("    ",kk,vv,c2); else L.push("    "+J(kk)+": "+J(vv)+c2);});
      L.push("  }"+c);
    }else L.push("  "+J(k)+": "+J(v)+c);
  });
  L.push("}"); return L.join("\n")+"\n";
}
function body(x){var c=clean(x);c.updated=0;return ser(c);} // для сравнения без отметки времени
function validate(){
  var b=data.bells, i;
  if(!b.length)return "Нужна хотя бы одна пара в звонках";
  for(i=0;i<b.length;i++){
    if(!/^\d{1,2}:\d\d$/.test(b[i][0]||"")||!/^\d{1,2}:\d\d$/.test(b[i][1]||""))return "Звонки: заполните время "+(i+1)+" пары";
    if(toMin(b[i][0])>=toMin(b[i][1]))return "Звонки: "+(i+1)+" пара заканчивается раньше, чем начинается";
    if(i&&toMin(b[i][0])<toMin(b[i-1][1]))return "Звонки: "+(i+1)+" пара начинается раньше конца "+i+"-й";
    if(b[i].length>2){
      if(!/^\d{1,2}:\d\d$/.test(b[i][2]||"")||!/^\d{1,2}:\d\d$/.test(b[i][3]||""))return "Звонки: заполните время пятиминутки "+(i+1)+" пары";
      if(!(toMin(b[i][0])<toMin(b[i][2])&&toMin(b[i][2])<toMin(b[i][3])&&toMin(b[i][3])<toMin(b[i][1])))return "Звонки: пятиминутка "+(i+1)+" пары должна быть внутри пары";
    }
  }
  if(!DATE_RE.test(data.end||""))return "Укажите последний день занятий";
  if(data.start&&!DATE_RE.test(data.start))return "Первый день занятий указан неверно";
  if(data.start&&data.start>data.end)return "Первый день занятий позже последнего";
  if(!DATE_RE.test(data.anchor||""))return "Укажите, какая сейчас неделя";
  for(i=0;i<data.lessons.length;i++){
    var l=data.lessons[i];
    if(!b[l.p-1])return DSHORT[l.d]+": "+l.p+" пары нет в звонках";
    if(!l.s)return DSHORT[l.d]+", "+l.p+" пара: не указан предмет";
    for(var j=i+1;j<data.lessons.length;j++){var o=data.lessons[j];
      if(o.d===l.d&&o.p===l.p&&(o.w===l.w||o.w==="all"||l.w==="all"))return DSHORT[l.d]+", "+l.p+" пара: две пары в одно время";}
  }
  for(var k in data.changes||{})for(i=0;i<data.changes[k].length;i++)if(!b[data.changes[k][i].p-1])return dlabel(k)+": такой пары нет в звонках";
  var s=data.session;
  if(s){
    if(!DATE_RE.test(s.from||"")||!DATE_RE.test(s.to||""))return "Сессия: укажите даты начала и конца";
    if(s.from>s.to)return "Сессия: конец раньше начала";
  }
  return "";
}
function fmt(json){var x=JSON.parse(json);x.updated=Date.now();return ser(clean(x));}
function bodyOf(json){return body(JSON.parse(json));}
function check(json){data=JSON.parse(json);if(!data.changes)data.changes={};return validate();}

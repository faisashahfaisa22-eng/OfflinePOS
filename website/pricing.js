/* QAMVIO public estimate calculator. Prices are illustrative and editable only in repository. */
(()=>{'use strict';
const catalog={
pos:[{id:'setup',name:'Android POS setup',price:9},{id:'inventory',name:'Inventory starter preparation (up to 20 products)',price:15},{id:'training',name:'Remote staff orientation (15 minutes)',price:7},{id:'records',name:'Business records workflow review',price:9}],
digital:[{id:'website',name:'One-page starter website (template-based)',price:19},{id:'store',name:'Starter store configuration (up to 5 products)',price:39},{id:'graphics',name:'5 social media graphics (template-based)',price:9}]};
document.querySelectorAll('[data-pricing-kind]').forEach(root=>{
const items=catalog[root.dataset.pricingKind]||[];const picker=root.querySelector('[data-service]');const qty=root.querySelector('[data-quantity]');const code=root.querySelector('[data-promo]');const details=root.querySelector('[data-pricing-result]');const cta=root.querySelector('[data-quote-link]');
items.forEach(x=>{const o=document.createElement('option');o.value=x.id;o.textContent=x.name+' — from $'+x.price.toFixed(2);picker.appendChild(o)});
const money=n=>new Intl.NumberFormat('en-US',{style:'currency',currency:'USD'}).format(n);
function recalc(){
const item=items.find(x=>x.id===picker.value)||items[0];const count=Math.max(1,Math.min(20,Math.floor(Number(qty.value)||1)));const subtotal=item.price*count;
const bundle=count>=3?10:count>=2?5:0;const promo=code.value.trim().toUpperCase()==='QAMVIO10'?10:0;const discount=Math.max(bundle,promo);const saved=Math.round(subtotal*discount)/100;const total=subtotal-saved;
details.textContent='Base estimate: '+money(subtotal)+' | Automatic discount: '+discount+'% (−'+money(saved)+') | Estimated total: '+money(total)+'.';
const subject='QAMVIO quote request: '+item.name;
const body='Service: '+item.name+'\nQuantity/packages: '+count+'\nIllustrative unit price: '+money(item.price)+'\nEstimated discount: '+discount+'%\nEstimated total: '+money(total)+'\nBusiness and country: \nProject requirements: \nPreferred contact time: \n\nPlease confirm the scope, final price and delivery schedule before requesting payment.';
cta.href='mailto:info@qamvio.com?subject='+encodeURIComponent(subject)+'&body='+encodeURIComponent(body);
}
[picker,qty,code].forEach(el=>el.addEventListener('input',recalc));recalc();
});
})();
// QAMVIO activation function placeholder.
// Requires server-side signing key provisioning before deployment.
Deno.serve(() => new Response(JSON.stringify({error:'not_configured'}), {status:503,headers:{'content-type':'application/json'}}));

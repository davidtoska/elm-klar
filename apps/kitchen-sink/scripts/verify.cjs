const { spawn, spawnSync } = require('node:child_process');
const path = require('node:path');
const fs = require('node:fs');
const root = path.resolve(__dirname,'..');
const results = path.join(root,'test-results');
fs.mkdirSync(results,{recursive:true});
const executable = path.join(results,process.platform==='win32'?'server-test.exe':'server-test');
const build = spawnSync(process.execPath,['scripts/go.cjs','build','-o',executable,'./server'],{cwd:root,stdio:'inherit'});
if(build.status!==0) process.exit(build.status||1);
const port=process.env.KITCHEN_SINK_TEST_PORT||'8091';
const url='http://127.0.0.1:'+port;
const server = spawn(executable,['-addr','127.0.0.1:'+port,'-db',path.join(results,'browser-'+Date.now()+'.sqlite')],{cwd:root,stdio:'pipe',windowsHide:true});
server.stderr.on('data',chunk=>process.stderr.write(chunk));
(async()=>{
  try {
    let ready=false;
    for(let attempt=0;attempt<100;attempt++) {
      if(server.exitCode!==null) throw new Error('Test server exited: '+server.exitCode);
      try {const response=await fetch(url+'/api/health');if(response.ok){ready=true;break}}catch{}
      await new Promise(resolve=>setTimeout(resolve,100));
    }
    if(!ready) throw new Error('Test server did not become ready');
    const code = await new Promise((resolve,reject)=>{
      const child=spawn(process.execPath,['scripts/browser-test.cjs'],{cwd:root,stdio:'inherit',env:{...process.env,KITCHEN_SINK_URL:url},windowsHide:true});
      child.on('error',reject);child.on('exit',resolve);
    });
    process.exitCode=code||0;
  } finally { server.kill(); }
})().catch(error=>{console.error(error);process.exitCode=1;server.kill()});

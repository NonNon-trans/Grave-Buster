#!/usr/bin/env python3
"""Execute the delivered Studio harness guards; reject every non-TEST context."""
from pathlib import Path
import subprocess,tempfile
source=Path('tests/studio/GB029ReleaseCandidateCheck.luau').read_text()
for forbidden in ['DataStoreService',':FireServer(',':InvokeServer(',':SetAttribute(',':TakeDamage(', 'Instance.new(', 'ServerScriptService']:
 assert forbidden not in source, f'Unexpected mutation/dependency in read-only harness: {forbidden}'
assert 'tests/studio' not in Path('default.project.json').read_text()
runner='local source=[====['+source+']====]\n'+'''
for _, case in {{false,true,0,0,"Studio only"},{true,false,0,0,"client context only"},{true,true,42,0,"configure TEST_UNIVERSE_ID first"},{true,true,42,99,"wrong TEST universe"}} do
 local services=0
 local environment=setmetatable({game={GameId=case[3],GetService=function(self,name)
  services+=1; assert(name=="RunService", "Guard allowed access beyond RunService")
  return {IsStudio=function() return case[1] end,IsClient=function() return case[2] end}
 end}}, {__index=getfenv(0)})
 local text=string.gsub(source,"local TEST_UNIVERSE_ID = 0","local TEST_UNIVERSE_ID = "..case[4],1)
 local fn=assert(loadstring(text)); setfenv(fn,environment)
 local ok,reason=pcall(fn)
 assert(not ok and string.find(tostring(reason),case[5],1,true), tostring(reason))
 assert(services==1)
end
print("PASS real-engine harness guards: Studio-only, client-only, explicit TEST id and exact universe; excluded from production mapping; read-only")
'''
with tempfile.TemporaryDirectory(prefix='gb028-guard-') as directory:
 p=Path(directory)/'guards.luau';p.write_text(runner)
 result=subprocess.run(['build/luau-tools/luau',str(p)],capture_output=True,text=True)
 print(result.stdout,end=''); print(result.stderr,end=''); raise SystemExit(result.returncode)

#!/usr/bin/env python3
"""Source-level audit only; never misrepresent as MATLAB execution."""
from pathlib import Path
import re, json, hashlib, shutil, difflib
root=Path(__file__).resolve().parent.parent
supplied=['blk1_txChannel.m','blk2_rx.m','blk3_tdoa.m','blk4_localize.m',
          'tdoaLocalize.m','tdoaModel.m','tdoaOptions.m','tdoaValidate.m',
          'tdoaWindowOptions.m','tdoaWindowStep.m']
created=['config.m','checkIO.m','blk5_track.m','tdoaStaticStep.m','main.m',
         'main_live.m','runCapstoneExperiment.m','runMonteCarlo.m',
         'plotCapstoneGeometry.m','plotCapstoneReport.m',
         'convert_live_to_mlx.m','run_integration_tests.m']
missing_original=['README.md','config.m','test_blk1.m','test_blk2.m','test_blk3.m',
                  'test_blk4.m','test_blk5.m','tdoaStaticStep.m','blk5_track.m','checkIO.m']
report={}
report['supplied_count']=len(supplied)
report['created_or_reconstructed_count']=len(created)
report['available_supplied_files']={f:(root/f).exists() for f in supplied}
report['new_files']={f:(root/f).exists() for f in created}
report['missing_from_supplied_uploads']=missing_original
report['original_preserved']={}
for f in supplied:
 a=(root/f).read_bytes(); b=(root/'original'/f).read_bytes()
 report['original_preserved'][f]=a==b
f=(root/'blk4_localize.m').read_text()
report['blk4_patch_present']='A failed line search is not automatically converged' in f
report['matlab_executable']=shutil.which('matlab')
report['octave_executable']=shutil.which('octave') or shutil.which('octave-cli')
report['can_run_matlab_tests']=bool(report['matlab_executable'])
report['native_mlx_verified']=(root/'presentation'/'main.mlx').exists()
matlab_files=list(root.glob('*.m'))
report['all_first_functions_match_files']={}
for p in matlab_files:
 s=p.read_text()
 m=re.search(r'^function\s+(?:(?:\[[^\]]*\]|[A-Za-z]\w*)\s*=\s*)?([A-Za-z]\w*)\s*\(',s,re.M)
 if m: report['all_first_functions_match_files'][p.name]=(m.group(1)==p.stem)
report['original_cfg_accesses']={}
for f in supplied:
 s=(root/'original'/f).read_text()
 report['original_cfg_accesses'][f]=sorted(set(re.findall(r'cfg\.([A-Za-z]\w*)',s)))
config=(root/'config.m').read_text()
cfg_fields=set(re.findall(r'^cfg\.([A-Za-z]\w*)\s*=',config,re.M))
missing_fields={f:sorted(set(fields)-cfg_fields) for f,fields in report['original_cfg_accesses'].items()}
report['original_cfg_fields_not_set_in_config']={f:v for f,v in missing_fields.items() if v}
run=(root/'runCapstoneExperiment.m').read_text()
positions=[run.find(s) for s in ['blk1_txChannel(', 'blk2_rx(', 'blk3_tdoa(', 'blk4_localize(', 'blk5_track(']]
checks=[run.find(s) for s in ['checkIO(1,', 'checkIO(2,', 'checkIO(3,', 'checkIO(4,', 'checkIO(5,']]
report['block_sequence_ordered']=positions==sorted(positions) and min(positions)>=0
report['checkio_after_each_block']=all(a>b for a,b in zip(checks,positions)) and checks==sorted(checks)
report['live_script_has_sections']=all(t in (root/'main_live.m').read_text() for t in [
 'System configuration','Block 1 - Transmitter','Block 2 - Receiver',
 'Block 3 - TDoA','Block 4 - Position','Block 5 - Tracking',
 'Final position estimate','Monte Carlo evaluation',
 'Performance comparisons'])
report['new_smoke_tests_present']=all((root/f'integration_test_blk{i}.m').exists() for i in range(1,6))
report['original_tests_present']=all((root/f'test_blk{i}.m').exists() for i in range(1,6))
report['matlab_tests_executed_here']=False
report['matlab_verified_functional']=False
report['notes']=[
 'A source scan is not a MATLAB syntax or runtime test.',
 'No original README, config or five original test scripts were supplied.',
 'tdoaStaticStep is reconstructed, not a recovered original.',
 'The MATLAB R2026a Live Editor must save main_live.m to main.mlx.',
 'Results, figures and numerical claims require execution in MATLAB R2026a.'
]
(root/'validation'/'static_audit.json').write_text(json.dumps(report,indent=2))
print(json.dumps({k:v for k,v in report.items() if k not in ['original_cfg_accesses','original_preserved','all_first_functions_match_files']},indent=2))
assert all(report['available_supplied_files'].values())
assert all(report['new_files'].values())
assert all(report['all_first_functions_match_files'].values())
assert report['block_sequence_ordered'] and report['checkio_after_each_block']
assert report['live_script_has_sections']

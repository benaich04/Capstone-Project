function outPath = convert_live_to_mlx()
%CONVERT_LIVE_TO_MLX Convert R2026a text live script to native .mlx in MATLAB.
% Requires MATLAB desktop Live Editor. This cannot be run without MATLAB.
root=fileparts(mfilename('fullpath'));
src=fullfile(root,'main_live.m');
outDir=fullfile(root,'presentation');
if ~exist(outDir,'dir'),mkdir(outDir);end
outPath=fullfile(outDir,'main.mlx');
doc=matlab.desktop.editor.openDocument(src);
doc.saveAs(outPath);
doc.closeNoPrompt();
if exist(outPath,'file')~=2
    error('convert_live_to_mlx:Failed','MATLAB did not create %s.',outPath);
end
fprintf('Verified MATLAB created native .mlx at %s\n',outPath);
end

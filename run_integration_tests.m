function summary = run_integration_tests()
%RUN_INTEGRATION_TESTS Run NEW integration smoke tests and report missing originals.
% The five original test_blk*.m files were not provided, so no claim about
% their outcomes is possible until they are copied into this folder.
fs={'integration_test_blk1','integration_test_blk2','integration_test_blk3', ...
    'integration_test_blk4','integration_test_blk5'};
summary=struct('newTestNames',{fs},'pass',false(1,5), ...
    'failureMessage',{cell(1,5)},'originalTestsAvailable',false(1,5));
fprintf('MATLAB %s | Checking five blocks\n',version);
for k=1:5
    original=sprintf('test_blk%d',k);
    summary.originalTestsAvailable(k)=exist(original,'file')==2;
    if ~summary.originalTestsAvailable(k)
        fprintf('Original %s.m: NOT PROVIDED (not run).\n',original);
    end
    try
        feval(fs{k});
        summary.pass(k)=true;
    catch ME
        summary.failureMessage{k}=getReport(ME,'extended','hyperlinks','off');
        fprintf(2,'FAIL %s: %s\n',fs{k},ME.message);
    end
end
fprintf('New integration smoke tests: %d/5 PASS.\n',nnz(summary.pass));
if ~all(summary.pass)
    error('run_integration_tests:Failures', ...
        'At least one integration smoke test failed. Inspect summary/failure output.');
end
end

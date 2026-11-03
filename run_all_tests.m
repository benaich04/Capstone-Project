function status = run_all_tests()
%RUN_ALL_TESTS Run the FIVE original team suites if supplied, then NEW tests.
% Missing original tests are NOT interpreted as passes.
status=struct('originalStatus',strings(1,5),'originalError',strings(1,5), ...
    'integrationStatus','not_started');
for k=1:5
    base=sprintf('test_blk%d',k);
    full=[base '.m'];
    if exist(full,'file')~=2
        status.originalStatus(k)="MISSING";
        fprintf(2,'MISSING original %s\n',full);
        continue
    end
    fprintf('Running original %s ...\n',full);
    try
        s=fileread(which(base));
        if ~isempty(regexp(s,'^\s*function\b','once'))
            feval(base);
        else
            run(which(base));
        end
        status.originalStatus(k)="PASS";
    catch ME
        status.originalStatus(k)="FAIL";
        status.originalError(k)=string(ME.message);
        fprintf(2,'FAIL original %s: %s\n',full,ME.message);
    end
end
try
    run_integration_tests();
    status.integrationStatus='PASS';
catch ME
    status.integrationStatus=['FAIL: ' ME.message];
end
if any(status.originalStatus~="PASS") || ~strcmp(status.integrationStatus,'PASS')
    disp(status);
    error('run_all_tests:Incomplete','Tests missing or failed; cannot claim full validation.');
end
disp('All original and new integration tests passed in this MATLAB session.');
end

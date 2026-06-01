function success = runScriptAndReturn(scriptPath)
    try
        [scriptDir, ~, ~] = fileparts(scriptPath);
        oldPath = addpath(scriptDir);
        cleanup = onCleanup(@() path(oldPath));
        run(scriptPath);
        success = true;
    catch ME
        fprintf('错误：%s\n', ME.message);
        fprintf('堆栈：\n');
        for k = 1:length(ME.stack)
            fprintf('  在 %s (行 %d)\n', ME.stack(k).name, ME.stack(k).line);
        end
        success = false;
    end
end

function switchCount = count_binary_switches(mask)
%COUNT_BINARY_SWITCHES logical mask의 on/off transition 횟수를 센다.

    mask = logical(mask(:));

    if isempty(mask)
        switchCount = 0;
        return;
    end

    switchCount = nnz(mask(2:end) ~= mask(1:end-1));
end

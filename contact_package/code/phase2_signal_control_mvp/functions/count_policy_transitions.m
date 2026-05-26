function switchCount = count_policy_transitions(policy)
%COUNT_POLICY_TRANSITIONS 최종 policy label의 변화 횟수를 센다.

    policy = string(policy(:));

    if isempty(policy)
        switchCount = 0;
        return;
    end

    switchCount = nnz(policy(2:end) ~= policy(1:end-1));
end

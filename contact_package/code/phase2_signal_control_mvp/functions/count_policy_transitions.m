function switchCount = count_policy_transitions(policy)
% 함수 설명:
%   정책 라벨 시퀀스에서 인접 윈도우 간 정책 변경 횟수를 계산합니다.
%
% 입력:
%   policy (문자열 벡터, 비어 있을 수 없음: 최종 정책 라벨 시퀀스입니다.)
%
% 출력:
%   switchCount (수치형 스칼라: 인접 원소가 달라지는 횟수입니다.)
%
% 예외:
%   필수 필드, 입력 차원, 파일 경로가 맞지 않으면 MATLAB 기본 예외가 발생할 수 있습니다.

    policy = string(policy(:));

    if isempty(policy)
        switchCount = 0;
        return;
    end

    switchCount = nnz(policy(2:end) ~= policy(1:end-1));
end

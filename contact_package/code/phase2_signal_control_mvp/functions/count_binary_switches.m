function switchCount = count_binary_switches(mask)
% 함수 설명:
%   이진 마스크에서 인접 값의 켜짐/꺼짐 전환 횟수를 계산합니다.
%
% 입력:
%   mask (논리형 또는 수치형 벡터, 비어 있을 수 없음: 에피소드 또는 전환 계산 대상 이진 시퀀스입니다.)
%
% 출력:
%   switchCount (수치형 스칼라: 인접 원소가 달라지는 횟수입니다.)
%
% 예외:
%   필수 필드, 입력 차원, 파일 경로가 맞지 않으면 MATLAB 기본 예외가 발생할 수 있습니다.

    mask = logical(mask(:));

    if isempty(mask)
        switchCount = 0;
        return;
    end

    switchCount = nnz(mask(2:end) ~= mask(1:end-1));
end

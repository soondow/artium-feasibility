function risk = normalize_mspc_score(mspcScore)
% 함수 설명:
%   MSPC 이상 점수를 Phase 2 제어기가 사용할 수 있는 제한된 위험 관측값으로 변환합니다.
%
% 입력:
%   mspcScore (수치형 배열, 비어 있을 수 없음: 정규화된 MSPC 이상 점수입니다.)
%
% 출력:
%   risk (수치형 배열: 0 이상 1 이하로 제한된 위험 관측값입니다.)
%
% 예외:
%   필수 필드, 입력 차원, 파일 경로가 맞지 않으면 MATLAB 기본 예외가 발생할 수 있습니다.

    risk = 0.12 + 0.58 * (1 - exp(-0.75 * mspcScore));
    risk = min(max(risk, 0), 1);
end

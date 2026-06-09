% 테스트 설명:
%   에피소드 기반 탐지 및 부담 지표가 겹치는 윈도우를 올바르게 병합하는지 검증합니다.
%
% 입력:
%   테스트 내부에서 정의한 합성 데이터, 프로젝트 함수, 또는 기존 산출물을 사용합니다.
%
% 출력:
%   조건을 만족하면 조용히 종료하고, 실패하면 assert 또는 error 예외가 발생합니다.
%
% 예외:
%   파일 경로, 내부 함수 입력 조건, 저장 과정에서 발생한 MATLAB 예외가 전파될 수 있습니다.


alertMask = [0 0 1 1 1 1 0 0 1 1 0]';
E = extract_binary_episodes(alertMask);

assert(height(E) == 2, 'Two alert episodes expected');
assert(E.start_idx(1) == 3 && E.stop_idx(1) == 6, 'First episode bounds are wrong');
assert(E.start_idx(2) == 9 && E.stop_idx(2) == 10, 'Second episode bounds are wrong');

Emerged = extract_binary_episodes(alertMask, 2);
assert(height(Emerged) == 1, 'Episodes separated by <= merge gap should merge');

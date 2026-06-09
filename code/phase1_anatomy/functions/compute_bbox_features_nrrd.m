function [bbox_x_mm, bbox_y_mm, bbox_z_mm, ...
          bbox_x_vox, bbox_y_vox, bbox_z_vox] = compute_bbox_features_nrrd(labVol, labInfo)
% 함수 설명:
%   NRRD 라벨 볼륨에서 좌심방 전경의 3차원 바운딩 박스 크기를 계산합니다.
%
% 입력:
%   labVol (수치형 배열, 비어 있을 수 없음: 좌심방 라벨 볼륨입니다. 0보다 큰 값은 전경으로 처리합니다.)
%   labInfo (구조체, 비어 있을 수 없음: PixelDimensions 필드를 포함하는 라벨 메타데이터입니다.)
%
% 출력:
%   bbox_x_mm (수치형 스칼라: x축 바운딩 박스 길이입니다.)
%   bbox_y_mm (수치형 스칼라: y축 바운딩 박스 길이입니다.)
%   bbox_z_mm (수치형 스칼라: z축 바운딩 박스 길이입니다.)
%   bbox_x_vox (수치형 스칼라: x축 복셀 단위 바운딩 박스 길이입니다.)
%   bbox_y_vox (수치형 스칼라: y축 복셀 단위 바운딩 박스 길이입니다.)
%   bbox_z_vox (수치형 스칼라: z축 복셀 단위 바운딩 박스 길이입니다.)
%
% 예외:
%   라벨 전경 복셀이 없으면 error를 발생시키며, PixelDimensions가 없으면 인덱싱 오류가 발생할 수 있습니다.
%
% 처리 절차:
%   1. 0보다 큰 라벨 값을 전경 마스크로 변환합니다.
%   2. 전경 복셀 좌표의 최솟값과 최댓값으로 축별 복셀 길이를 계산합니다.
%   3. 복셀 길이에 PixelDimensions를 곱해 물리 길이를 계산합니다.

    labMask = labVol > 0;
    [x, y, z] = ind2sub(size(labMask), find(labMask));

    if isempty(x)
        error('라벨 비었음. bbox 계산 불가.');
    end
    bbox_x_vox = max(x) - min(x) + 1;
    bbox_y_vox = max(y) - min(y) + 1;
    bbox_z_vox = max(z) - min(z) + 1;
    spacing = labInfo.PixelDimensions;
    bbox_x_mm = bbox_x_vox * spacing(1);
    bbox_y_mm = bbox_y_vox * spacing(2);
    bbox_z_mm = bbox_z_vox * spacing(3);
end

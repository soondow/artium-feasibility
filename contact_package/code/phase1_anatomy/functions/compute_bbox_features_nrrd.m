function [bbox_x_mm, bbox_y_mm, bbox_z_mm, ...
          bbox_x_vox, bbox_y_vox, bbox_z_vox] = compute_bbox_features_nrrd(labVol, labInfo)

    labMask = labVol > 0;
    %좌표 찾기
    [x, y, z] = ind2sub(size(labMask), find(labMask));

    if isempty(x)
        error('라벨 비었음. bbox 계산 불가.');
    end
    % 복셀 단위 bbox 길이
    bbox_x_vox = max(x) - min(x) + 1;
    bbox_y_vox = max(y) - min(y) + 1;
    bbox_z_vox = max(z) - min(z) + 1;
    % 간격 정보
    spacing = labInfo.PixelDimensions; % [dx, dy, dz] 간격
    % mm 단위 길이
    bbox_x_mm = bbox_x_vox * spacing(1);
    bbox_y_mm = bbox_y_vox * spacing(2);
    bbox_z_mm = bbox_z_vox * spacing(3);
end

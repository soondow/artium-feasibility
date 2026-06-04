alertMask = [0 0 1 1 1 1 0 0 1 1 0]';
E = extract_binary_episodes(alertMask);

assert(height(E) == 2, 'Two alert episodes expected');
assert(E.start_idx(1) == 3 && E.stop_idx(1) == 6, 'First episode bounds are wrong');
assert(E.start_idx(2) == 9 && E.stop_idx(2) == 10, 'Second episode bounds are wrong');

Emerged = extract_binary_episodes(alertMask, 2);
assert(height(Emerged) == 1, 'Episodes separated by <= merge gap should merge');


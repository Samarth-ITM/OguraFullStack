/**
 * Presentation-only sample QR graphic used for MVP demo payment testing.
 * It encodes nothing and performs no payment.
 */
const SIZE = 21;

function cells(): boolean[][] {
  const grid: boolean[][] = [];
  for (let y = 0; y < SIZE; y += 1) {
    const row: boolean[] = [];
    for (let x = 0; x < SIZE; x += 1) {
      // deterministic pseudo-pattern (no randomness, SSR-safe)
      row.push(((x * 7 + y * 13 + ((x * y) % 5)) % 3) === 0);
    }
    grid.push(row);
  }
  // finder patterns
  const finder = (ox: number, oy: number) => {
    for (let y = 0; y < 7; y += 1) {
      for (let x = 0; x < 7; x += 1) {
        const edge = x === 0 || y === 0 || x === 6 || y === 6;
        const core = x >= 2 && x <= 4 && y >= 2 && y <= 4;
        const row = grid[oy + y];
        if (row) row[ox + x] = edge || core;
      }
    }
  };
  finder(0, 0);
  finder(SIZE - 7, 0);
  finder(0, SIZE - 7);
  return grid;
}

export function DemoQr({ className }: { className?: string }) {
  const grid = cells();
  return (
    <svg
      viewBox={`0 0 ${SIZE} ${SIZE}`}
      className={className}
      role="img"
      aria-label="Sample demo QR code"
      shapeRendering="crispEdges"
    >
      <rect width={SIZE} height={SIZE} fill="#ffffff" />
      {grid.map((row, y) =>
        row.map((on, x) =>
          on ? <rect key={`${x}-${y}`} x={x} y={y} width={1} height={1} fill="#111111" /> : null,
        ),
      )}
    </svg>
  );
}

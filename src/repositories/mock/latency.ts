export type SimulatedState = "normal" | "loading" | "empty" | "error";

let simulated: SimulatedState = "normal";
const listeners = new Set<() => void>();

export function getSimulatedState(): SimulatedState {
  return simulated;
}

export function setSimulatedState(state: SimulatedState): void {
  simulated = state;
  listeners.forEach((l) => l());
}

export function subscribeSimulatedState(listener: () => void): () => void {
  listeners.add(listener);
  return () => listeners.delete(listener);
}

function stableDelay(key: string): number {
  let n = 0;
  for (let i = 0; i < key.length; i += 1) n = (n * 31 + key.charCodeAt(i)) % 151;
  return 150 + n;
}

export async function simulate<T>(key: string, value: () => T): Promise<T> {
  const state = simulated;
  if (state === "loading") {
    await new Promise(() => {});
  }
  await new Promise((resolve) => setTimeout(resolve, stableDelay(key)));
  if (state === "error") throw new Error("Simulated repository error");
  return value();
}

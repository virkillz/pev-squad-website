// Browser preview credentials live only in memory; never in localStorage.
let saved: string | null = null;
export const readSession = async () => saved;
export const writeSession = async (value: string | null) => { saved = value; };

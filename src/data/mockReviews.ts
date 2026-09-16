export interface MockReview {
  id: string;
  productId: string;
  author: string;
  rating: number;
  title: string;
  body: string;
  fitFeedback: "Runs small" | "True to size" | "Runs large";
  createdAt: string;
  hasMedia: boolean;
}

const AUTHORS = ["Aditi R.", "Nikita S.", "Meher K.", "Rhea T.", "Ishani B.", "Tara M.", "Sana V.", "Priya D."];
const TITLES = [
  "Beautiful construction",
  "Exactly as pictured",
  "Wore it twice already",
  "Fabric feels considered",
  "Great cut, small fit note",
  "Worth the wait",
];
const BODIES = [
  "The finishing is neat and the silhouette holds its shape well through the day.",
  "Colour reads slightly deeper in daylight, which I actually preferred.",
  "Sizing was accurate for me. The detailing near the seams is genuinely well done.",
  "Comfortable for long evenings and it photographs beautifully.",
  "I sized up for a relaxed drape and it worked exactly as I hoped.",
];
const FITS: MockReview["fitFeedback"][] = ["Runs small", "True to size", "True to size", "Runs large"];

function hash(s: string) {
  let n = 0;
  for (let i = 0; i < s.length; i += 1) n = (n * 33 + s.charCodeAt(i)) % 100000;
  return n;
}

export function reviewsForProduct(productId: string, count: number): MockReview[] {
  const total = Math.min(count, 8);
  return Array.from({ length: total }, (_, i) => {
    const h = hash(productId + i);
    return {
      id: `${productId}-R${i + 1}`,
      productId,
      author: AUTHORS[h % AUTHORS.length] ?? "OGURA customer",
      rating: [5, 4, 5, 3, 4][h % 5] ?? 4,
      title: TITLES[h % TITLES.length] ?? "Lovely piece",
      body: BODIES[h % BODIES.length] ?? "A considered piece that wears well.",
      fitFeedback: FITS[h % FITS.length] ?? "True to size",
      createdAt: new Date(2025, h % 12, (h % 27) + 1).toISOString().slice(0, 10),
      hasMedia: h % 3 === 0,
    };
  });
}

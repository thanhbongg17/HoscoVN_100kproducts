import { PrismaClient } from '@prisma/client';
const db = new PrismaClient();

const TOTAL = 100_000;   // Seed đúng 100k
const BATCH = 10_000;    // mỗi lượt 10k (nếu máy yếu, đổi 5_000)

const randPrice = () => Math.floor(10_000 + Math.random() * 990_000);

async function main() {
  let inserted = 0;

  while (inserted < TOTAL) {
    const n = Math.min(BATCH, TOTAL - inserted);

    // Lấy id lớn nhất hiện có để suy ra dải id mới sau khi insert
    const last = await db.product.findFirst({
      orderBy: { id: 'desc' },
      select: { id: true },
    });
    const startId = (last?.id ?? 0) + 1;

    // KHÔNG truyền id => SQL Server tự tăng IDENTITY
    const productRows = Array.from({ length: n }, (_, i) => ({
      name: `Sản phẩm ${startId + i}`,
      unit: 'cái',
      price: randPrice(),
    }));
    await db.product.createMany({ data: productRows });

    // Dải id mới vừa sinh
    const ids = Array.from({ length: n }, (_, i) => startId + i);

    // Tồn kho: đúng đề bài => luôn 10
    await db.inventory.createMany({
      data: ids.map((id) => ({ productId: id, stock: 10 })),
    });

    // Mỗi sp 2 asset (ảnh + video, chỉ là URL)
    await db.mediaAsset.createMany({
      data: ids.flatMap((id) => [
        {
          productId: id,
          type: 'image',
          url: `https://picsum.photos/seed/${id}/400/300`,
          sizeBytes: 200_000,
          isPrimary: true,
          sortOrder: 0,
        },
        {
          productId: id,
          type: 'video',
          url: 'https://samplelib.com/lib/preview/mp4/sample-5s.mp4',
          sizeBytes: 700_000,
          isPrimary: false,
          sortOrder: 1,
        },
      ]),
    });

    console.log(`Seeded ${startId}..${startId + n - 1}`);
    inserted += n;
  }
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(() => db.$disconnect());

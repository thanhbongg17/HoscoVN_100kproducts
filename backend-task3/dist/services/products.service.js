// services/productService.ts
import { ProductModel } from '../model/products.model.js'; // Import model
// Helper ép kiểu an toàn
const toId = (v) => typeof v === 'bigint' ? Number(v) : parseInt(String(v ?? 0), 10);
const toNum = (v) => v && typeof v === 'object' && 'toNumber' in v ? v.toNumber() : Number(v);
function pickOne(arr, type) {
    const list = (arr || []).filter((m) => m.type === type);
    if (!list.length)
        return null;
    const primary = list.find((m) => m.isPrimary);
    return primary ?? list.sort((a, b) => (a.sortOrder ?? 0) - (b.sortOrder ?? 0))[0];
}
export const ProductService = {
    // Lấy tất cả sản phẩm và tổng số sản phẩm với phân trang
    getProductsWithPagination: async (page, size) => {
        const startService = Date.now();
        const [rows, total] = await Promise.all([
            ProductModel.getAll(page, size), // rows có cả media
            ProductModel.count(),
        ]);
        // Map lại rows sang shape FE cần
        const items = rows.map((p) => {
            const image = pickOne(p.media ?? [], 'image');
            const video = pickOne(p.media ?? [], 'video');
            return {
                id: toId(p.id),
                name: p.name ?? '',
                unit: p.unit ?? '',
                price: toNum(p.price),
                imageUrl: image?.url ?? null,
                videoUrl: video?.url ?? null,
            };
        });
        console.info(`Service processing time: ${Date.now() - startService}ms`);
        return {
            items,
            total,
            hasNext: page * size < total,
            ids: items.map((p) => p.id),
        };
    },
};

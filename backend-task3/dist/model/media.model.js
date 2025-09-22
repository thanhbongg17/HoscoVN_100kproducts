// src/app/models/media.model.ts
import { db } from '../db.js';
export class MediaModel {
    static async findByProductIds(ids) {
        return db.mediaAsset.findMany({
            where: { productId: { in: ids } },
            orderBy: [
                { isPrimary: 'desc' },
                { sortOrder: 'asc' },
                { id: 'asc' }
            ],
            select: { productId: true, type: true, url: true, sizeBytes: true, isPrimary: true },
        });
    }
}

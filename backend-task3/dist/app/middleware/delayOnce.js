// Delay 1 lần cho MỖI request (không nhân theo số sản phẩm)
export const delayOnce = (ms) => {
    return async (_req, _res, next) => {
        if (ms > 0) {
            await new Promise(r => setTimeout(r, ms));
        }
        next();
    };
};
// (tuỳ chọn) Delay theo query: ?delayMs=10000
export const delayFromQuery = async (req, _res, next) => {
    const ms = Number(req.query.delayMs ?? 0);
    if (Number.isFinite(ms) && ms > 0) {
        await new Promise(r => setTimeout(r, ms));
    }
    next();
};

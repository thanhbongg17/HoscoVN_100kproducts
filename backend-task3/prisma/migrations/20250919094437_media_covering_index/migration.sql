-- This is an empty migration.
BEGIN TRY
BEGIN TRAN;

-- (Tuỳ chọn) Xoá index cũ nếu muốn thay thế để tránh thừa index
IF EXISTS (
  SELECT 1 FROM sys.indexes
  WHERE name = 'MediaAsset_productId_isPrimary_sortOrder_idx'
    AND object_id = OBJECT_ID('dbo.MediaAsset')
)
BEGIN
  DROP INDEX [MediaAsset_productId_isPrimary_sortOrder_idx]
  ON [dbo].[MediaAsset];
END

-- Covering index cho truy vấn /media:
-- WHERE productId IN (...)
-- ORDER BY isPrimary DESC, sortOrder ASC, id ASC
-- SELECT các cột: type, url, isPrimary, sortOrder
IF NOT EXISTS (
  SELECT 1 FROM sys.indexes
  WHERE name = 'IX_MediaAsset_Product_PrimarySort_Cover'
    AND object_id = OBJECT_ID('dbo.MediaAsset')
)
BEGIN
  CREATE INDEX [IX_MediaAsset_Product_PrimarySort_Cover]
  ON [dbo].[MediaAsset] (
    [productId] ASC,
    [isPrimary] DESC,
    [sortOrder] ASC,
    [id] ASC
  )
  INCLUDE ( [type], [url] );
END

COMMIT TRAN;
END TRY
BEGIN CATCH
  IF @@TRANCOUNT > 0 ROLLBACK TRAN;
  THROW;
END CATCH;

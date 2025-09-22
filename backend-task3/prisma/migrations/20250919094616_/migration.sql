BEGIN TRY

BEGIN TRAN;

-- DropIndex
DROP INDEX [IX_MediaAsset_Product_PrimarySort_Cover] ON [dbo].[MediaAsset];

-- CreateIndex
CREATE NONCLUSTERED INDEX [MediaAsset_productId_isPrimary_sortOrder_idx] ON [dbo].[MediaAsset]([productId], [isPrimary], [sortOrder]);

COMMIT TRAN;

END TRY
BEGIN CATCH

IF @@TRANCOUNT > 0
BEGIN
    ROLLBACK TRAN;
END;
THROW

END CATCH

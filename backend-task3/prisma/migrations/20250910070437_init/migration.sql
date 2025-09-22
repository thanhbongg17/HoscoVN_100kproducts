BEGIN TRY

BEGIN TRAN;

-- CreateTable
CREATE TABLE [dbo].[Product] (
    [id] INT NOT NULL IDENTITY(1,1),
    [name] NVARCHAR(255) NOT NULL,
    [unit] NVARCHAR(50) NOT NULL CONSTRAINT [Product_unit_df] DEFAULT 'cái',
    [price] INT NOT NULL,
    CONSTRAINT [Product_pkey] PRIMARY KEY CLUSTERED ([id])
);

-- CreateTable
CREATE TABLE [dbo].[Inventory] (
    [productId] INT NOT NULL,
    [stock] INT NOT NULL,
    CONSTRAINT [Inventory_pkey] PRIMARY KEY CLUSTERED ([productId])
);

-- CreateTable
CREATE TABLE [dbo].[MediaAsset] (
    [id] INT NOT NULL IDENTITY(1,1),
    [productId] INT NOT NULL,
    [type] NVARCHAR(10) NOT NULL,
    [url] NVARCHAR(1000) NOT NULL,
    [sizeBytes] INT NOT NULL,
    [isPrimary] BIT NOT NULL CONSTRAINT [MediaAsset_isPrimary_df] DEFAULT 0,
    [sortOrder] INT NOT NULL CONSTRAINT [MediaAsset_sortOrder_df] DEFAULT 0,
    CONSTRAINT [MediaAsset_pkey] PRIMARY KEY CLUSTERED ([id])
);

-- CreateIndex
CREATE NONCLUSTERED INDEX [MediaAsset_productId_isPrimary_sortOrder_idx] ON [dbo].[MediaAsset]([productId], [isPrimary], [sortOrder]);

-- AddForeignKey
ALTER TABLE [dbo].[Inventory] ADD CONSTRAINT [Inventory_productId_fkey] FOREIGN KEY ([productId]) REFERENCES [dbo].[Product]([id]) ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE [dbo].[MediaAsset] ADD CONSTRAINT [MediaAsset_productId_fkey] FOREIGN KEY ([productId]) REFERENCES [dbo].[Product]([id]) ON DELETE CASCADE ON UPDATE CASCADE;

COMMIT TRAN;

END TRY
BEGIN CATCH

IF @@TRANCOUNT > 0
BEGIN
    ROLLBACK TRAN;
END;
THROW

END CATCH

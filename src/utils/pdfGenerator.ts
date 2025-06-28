import jsPDF from 'jspdf';

interface ReceiptData {
  customerName: string;
  customerPhone: string;
  customerEmail?: string;
  items: Array<{
    name: string;
    quantity: number;
    unitPrice: number;
    isRental: boolean;
    rentalDays?: number;
    discount?: number;
    discountAmount?: number;
  }>;
  subtotal: number;
  totalDiscount?: number;
  total: number;
  paidAmount?: number;
  remainingAmount?: number;
  date: Date;
  agentName: string;
  receiptNumber?: string;
}

export function generateReceiptPDF(data: ReceiptData): void {
  const doc = new jsPDF();
  const pageWidth = doc.internal.pageSize.width;
  const margin = 20;
  let yPosition = 20;

  // Header - Store Info
  doc.setFontSize(24);
  doc.setFont('helvetica', 'bold');
  doc.text('HaliStock Boutique', pageWidth / 2, yPosition, { align: 'center' });

  yPosition += 10;
  doc.setFontSize(12);
  doc.setFont('helvetica', 'normal');
  doc.text('Système de Gestion de Vêtements', pageWidth / 2, yPosition, { align: 'center' });

  yPosition += 5;
  doc.text('1200 logts', pageWidth / 2, yPosition, { align: 'center' });

  yPosition += 5;
  doc.text('Tél: +213668979699', pageWidth / 2, yPosition, { align: 'center' });

  yPosition += 15;
  doc.line(margin, yPosition, pageWidth - margin, yPosition);
  yPosition += 15;

  // Receipt Title
  doc.setFontSize(18);
  doc.setFont('helvetica', 'bold');
  doc.text('REÇU DE VENTE', pageWidth / 2, yPosition, { align: 'center' });
  yPosition += 15;

  // Receipt Info
  doc.setFontSize(10);
  doc.setFont('helvetica', 'normal');

  const receiptNumber = data.receiptNumber || `REC-${Date.now()}`;
  doc.text(`N° Reçu: ${receiptNumber}`, margin, yPosition);
  doc.text(`Date: ${data.date.toLocaleDateString('fr-FR')} ${data.date.toLocaleTimeString('fr-FR')}`, pageWidth - margin, yPosition, { align: 'right' });
  yPosition += 10;

  doc.text(`Agent: ${data.agentName}`, margin, yPosition);
  yPosition += 15;

  // Customer Info
  doc.setFont('helvetica', 'bold');
  doc.text('INFORMATIONS CLIENT:', margin, yPosition);
  yPosition += 8;

  doc.setFont('helvetica', 'normal');
  doc.text(`Nom: ${data.customerName}`, margin, yPosition);
  yPosition += 6;
  doc.text(`Téléphone: ${data.customerPhone}`, margin, yPosition);
  yPosition += 6;

  if (data.customerEmail) {
    doc.text(`Email: ${data.customerEmail}`, margin, yPosition);
    yPosition += 6;
  }

  yPosition += 10;

  // Items Header
  doc.setFont('helvetica', 'bold');
  doc.text('DÉTAIL DES ARTICLES:', margin, yPosition);
  yPosition += 10;

  // Table Header
  doc.setFontSize(9);
  const colWidths = [70, 15, 25, 25, 25, 30];
  const colPositions = [
    margin,
    margin + colWidths[0],
    margin + colWidths[0] + colWidths[1],
    margin + colWidths[0] + colWidths[1] + colWidths[2],
    margin + colWidths[0] + colWidths[1] + colWidths[2] + colWidths[3],
    margin + colWidths[0] + colWidths[1] + colWidths[2] + colWidths[3] + colWidths[4]
  ];

  doc.text('Article', colPositions[0], yPosition);
  doc.text('Qté', colPositions[1], yPosition);
  doc.text('Prix Unit.', colPositions[2], yPosition);
  doc.text('Type', colPositions[3], yPosition);
  doc.text('Réduction', colPositions[4], yPosition);
  doc.text('Total', colPositions[5], yPosition);

  yPosition += 5;
  doc.line(margin, yPosition, pageWidth - margin, yPosition);
  yPosition += 8;

  // Items
  doc.setFont('helvetica', 'normal');
  data.items.forEach((item) => {
    const itemSubtotal = item.quantity * item.unitPrice;
    const itemTotal = itemSubtotal - (item.discountAmount || 0);

    doc.text(item.name.substring(0, 20), colPositions[0], yPosition);
    doc.text(item.quantity.toString(), colPositions[1], yPosition);
    doc.text(`${item.unitPrice.toFixed(2)}`, colPositions[2], yPosition);

    let typeText = item.isRental ? 'Location' : 'Vente';
    if (item.isRental && item.rentalDays) {
      typeText += ` (${item.rentalDays}j)`;
    }
    doc.text(typeText, colPositions[3], yPosition);

    if (item.discount && item.discount > 0) {
      doc.text(`${item.discount}%`, colPositions[4], yPosition);
    } else {
      doc.text('-', colPositions[4], yPosition);
    }

    doc.text(`${itemTotal.toFixed(2)}`, colPositions[5], yPosition);

    yPosition += 8;
  });

  // Totals
  yPosition += 5;
  doc.line(margin, yPosition, pageWidth - margin, yPosition);
  yPosition += 10;

  doc.setFontSize(10);
  doc.setFont('helvetica', 'normal');

  // Sous-total
  doc.text('Sous-total:', pageWidth - margin - 60, yPosition);
  doc.text(`${data.subtotal.toFixed(2)} DA`, pageWidth - margin, yPosition, { align: 'right' });
  yPosition += 8;

  // Réductions totales
  if (data.totalDiscount && data.totalDiscount > 0) {
    doc.setTextColor(0, 150, 0);
    doc.text('Réductions:', pageWidth - margin - 60, yPosition);
    doc.text(`-${data.totalDiscount.toFixed(2)} DA`, pageWidth - margin, yPosition, { align: 'right' });
    yPosition += 8;
    doc.setTextColor(0, 0, 0);
  }

  // Total
  doc.setFontSize(12);
  doc.setFont('helvetica', 'bold');
  doc.text('TOTAL À PAYER:', pageWidth - margin - 60, yPosition);
  doc.text(`${data.total.toFixed(2)} DA`, pageWidth - margin, yPosition, { align: 'right' });
  yPosition += 10;

  // Paiement
  if (data.paidAmount !== undefined) {
    doc.setFontSize(10);
    doc.setFont('helvetica', 'normal');
    doc.setTextColor(0, 0, 200);
    doc.text('Montant payé:', pageWidth - margin - 60, yPosition);
    doc.text(`${data.paidAmount.toFixed(2)} DA`, pageWidth - margin, yPosition, { align: 'right' });
    yPosition += 8;

    if (data.remainingAmount && data.remainingAmount > 0) {
      doc.setTextColor(200, 100, 0);
      doc.text('Reste à payer:', pageWidth - margin - 60, yPosition);
      doc.text(`${data.remainingAmount.toFixed(2)} DA`, pageWidth - margin, yPosition, { align: 'right' });
      yPosition += 8;
    }
    doc.setTextColor(0, 0, 0);
  }

  yPosition += 10;

  // Rental Info
  const hasRentals = data.items.some(item => item.isRental);
  if (hasRentals) {
    doc.setFontSize(10);
    doc.setFont('helvetica', 'bold');
    doc.text('INFORMATIONS LOCATION:', margin, yPosition);
    yPosition += 8;

    doc.setFont('helvetica', 'normal');
    data.items.forEach((item) => {
      if (item.isRental && item.rentalDays) {
        const returnDate = new Date(data.date);
        returnDate.setDate(returnDate.getDate() + item.rentalDays);
        doc.text(`${item.name}: À retourner le ${returnDate.toLocaleDateString('fr-FR')}`, margin, yPosition);
        yPosition += 6;
      }
    });
    yPosition += 10;
  }

  // Footer
  yPosition += 10;
  doc.line(margin, yPosition, pageWidth - margin, yPosition);
  yPosition += 10;

  doc.setFontSize(9);
  doc.setFont('helvetica', 'italic');
  doc.text('Merci pour votre confiance !', pageWidth / 2, yPosition, { align: 'center' });
  yPosition += 6;
  doc.text('Conservez ce reçu comme preuve d\'achat', pageWidth / 2, yPosition, { align: 'center' });
  yPosition += 6;
  doc.text('Échanges et remboursements selon conditions en magasin', pageWidth / 2, yPosition, { align: 'center' });

  // Save
  const fileName = `Recu_${data.customerName.replace(/\s+/g, '_')}_${data.date.toISOString().split('T')[0]}.pdf`;
  doc.save(fileName);
}
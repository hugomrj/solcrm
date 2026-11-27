# helpers/pdf_helpers.rb
require "prawn"
require "prawn/table"

module PdfHelpers
  # Prawn avisa que las fuentes AFM no cubren todo el UTF-8.
  # La factura usa textos en latin-1 (ñ, á, é) que sí están cubiertos.
  Prawn::Fonts::AFM.hide_m17n_warning = true

  # Genera el PDF de una factura con Prawn (Ruby puro, sin binarios externos).
  # Devuelve un String con el contenido binario del PDF.
  def factura_pdf(factura, cliente, items)
    Prawn::Document.new(page_size: "A4", margin: [40, 40, 40, 40]) do |pdf|
      # ---- Encabezado ----
      pdf.text "SolCRM", size: 22, style: :bold
      pdf.text "Tu empresa S.A. - RUC: 80012345-6", size: 9, color: "666666"
      pdf.move_down 6
      pdf.stroke_horizontal_rule
      pdf.move_down 12

      pdf.text "FACTURA #{factura[:numero]}", size: 16, style: :bold, align: :right
      pdf.move_down 10

      # ---- Datos del cliente ----
      pdf.text "Cliente: #{cliente ? cliente[:nombre] : '—'}", size: 11
      pdf.text "Fecha: #{format_fecha(factura[:fecha])}", size: 11
      pdf.text "Vencimiento: #{format_fecha(factura[:vencimiento])}", size: 11 if factura[:vencimiento]
      pdf.text "Estado: #{factura[:estado].to_s.upcase}", size: 11
      pdf.move_down 14

      # ---- Ítems ----
      ancho = pdf.bounds.width
      filas = [["Descripción", "Cant.", "Precio", "Total"]]
      items.each do |it|
        filas << [
          it[:descripcion].to_s,
          numero_cantidad(it[:cantidad]),
          "Gs. #{number_with_delimiter(it[:precio])}",
          "Gs. #{number_with_delimiter(it[:total])}"
        ]
      end

      pdf.table(
        filas,
        header: true,
        width: ancho,
        column_widths: [ancho - 260, 55, 105, 100],
        cell_style: { size: 9, padding: [5, 6, 5, 6], border_width: 0.5 }
      ) do |t|
        t.row(0).font_style = :bold
        t.row(0).background_color = "EEEEEE"
        t.column(1).align = :right
        t.column(2).align = :right
        t.column(3).align = :right
        t.cells.border_color = "CCCCCC"
      end

      # ---- Totales ----
      pdf.move_down 14
      pdf.text "Subtotal: Gs. #{number_with_delimiter(factura[:subtotal])}", align: :right, size: 11
      pdf.text "IVA (10%): Gs. #{number_with_delimiter(factura[:impuestos])}", align: :right, size: 11
      pdf.move_down 4
      pdf.text "Total: Gs. #{number_with_delimiter(factura[:total])}",
               align: :right, size: 14, style: :bold

      # ---- Notas ----
      notas = factura[:notas].to_s.strip
      unless notas.empty?
        pdf.move_down 24
        pdf.stroke_horizontal_rule
        pdf.move_down 8
        pdf.text "Notas:", size: 10, style: :bold
        pdf.text notas, size: 9
      end
    end.render
  end

  private

  def format_fecha(valor)
    valor.to_s.empty? ? "—" : valor.to_s
  end

  def numero_cantidad(valor)
    entero = valor.to_f
    entero == entero.round ? entero.round.to_s : format("%.2f", entero)
  end
end

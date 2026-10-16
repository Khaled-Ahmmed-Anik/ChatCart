class PhotoImageNormalizer
  class InvalidImage < StandardError; end

  def normalize(bytes)
    raise InvalidImage if bytes.bytesize > Constants::PhotoRecognition::MAX_DOWNLOAD_BYTES

    require "vips"
    image = Vips::Image.new_from_buffer(bytes, "", access: :sequential, fail_on: :warning)
    validate_dimensions!(image)
    largest_edge = Constants::PhotoRecognition::ENCODING_OPTIONS.first.first
    image = image.autorot.thumbnail_image(largest_edge, height: largest_edge, size: :down)
    image = image.flatten(background: [ 255, 255, 255 ]) if image.has_alpha?
    # Retain only bounded, resized pixels: retries must not reread a sequential decoder.
    image = image.colourspace(:srgb).copy_memory
    Constants::PhotoRecognition::ENCODING_OPTIONS.each do |edge, quality|
      resized = image.thumbnail_image(edge, height: edge, size: :down)
      encoded = resized.write_to_buffer(".jpg", Q: quality, strip: true)
      return encoded if encoded.bytesize <= Constants::PhotoRecognition::MAX_IMAGE_BYTES
    end
    raise InvalidImage
  rescue LoadError, StandardError => error
    raise InvalidImage, error.class.name
  end

  private

  def validate_dimensions!(image)
    dimensions = [ image.width, image.height ]
    raise InvalidImage unless dimensions.all? { |value| value.positive? && value <= Constants::PhotoRecognition::MAX_IMAGE_DIMENSION }
    raise InvalidImage if image.width * image.height > Constants::PhotoRecognition::MAX_IMAGE_PIXELS
    raise InvalidImage if image.get_typeof("n-pages").positive? && image.get("n-pages") > 1
  end
end

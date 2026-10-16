require "test_helper"
require "vips"

class PhotoImageNormalizerTest < ActiveSupport::TestCase
  test "large phone-sized image is resized to bounded JPEG without upscaling" do
    input = Vips::Image.gaussnoise(2000, 1500).cast(:uchar).write_to_buffer(".png")
    assert_operator input.bytesize, :>, Constants::PhotoRecognition::MAX_IMAGE_BYTES
    result = PhotoImageNormalizer.new.normalize(input)
    assert_operator result.bytesize, :<=, Constants::PhotoRecognition::MAX_IMAGE_BYTES
    image = Vips::Image.new_from_buffer(result, "")
    assert_operator image.width, :<=, Constants::PhotoRecognition::ENCODING_OPTIONS.first.first
    assert_equal image.width * 3, image.height * 4
    assert result.start_with?("\xFF\xD8\xFF".b)
  end

  test "orientation is applied and image metadata is stripped" do
    input = Vips::Image.black(80, 40, bands: 3)
    input.set_type(GObject::GINT_TYPE, "orientation", 6)
    input.set_type(GObject::GSTR_TYPE, "exif-ifd0-Artist", "Private Owner")
    jpeg = input.write_to_buffer(".jpg")
    result = Vips::Image.new_from_buffer(PhotoImageNormalizer.new.normalize(jpeg), "")
    assert_equal [ 40, 80 ], [ result.width, result.height ]
    assert_equal 0, result.get_typeof("exif-ifd0-Artist")
    assert_equal 0, result.get_typeof("exif-data")
  end

  test "transparent images use a white background" do
    input = Vips::Image.black(20, 10, bands: 4).write_to_buffer(".png")
    result = Vips::Image.new_from_buffer(PhotoImageNormalizer.new.normalize(input), "")
    assert_equal [ 20, 10 ], [ result.width, result.height ]
    assert result.getpoint(0, 0).all? { |channel| channel >= 253 }
  end

  test "corrupt images and excessive downloads or pixel dimensions are rejected" do
    inputs = [ "\xFF\xD8\xFFbroken".b,
      "x" * (Constants::PhotoRecognition::MAX_DOWNLOAD_BYTES + 1),
      Vips::Image.black(6000, 5000).write_to_buffer(".png"),
      Vips::Image.black(Constants::PhotoRecognition::MAX_IMAGE_DIMENSION + 1, 1).write_to_buffer(".png") ]
    inputs.each do |input|
      assert_raises(PhotoImageNormalizer::InvalidImage) { PhotoImageNormalizer.new.normalize(input) }
    end
  end

  test "animated images are rejected instead of silently selecting a frame" do
    red = Vips::Image.black(16, 16, bands: 3).new_from_image([ 255, 0, 0 ])
    blue = red.new_from_image([ 0, 0, 255 ])
    input = red.join(blue, :vertical).write_to_buffer(".webp", page_height: 16)
    assert_raises(PhotoImageNormalizer::InvalidImage) { PhotoImageNormalizer.new.normalize(input) }
  end
end

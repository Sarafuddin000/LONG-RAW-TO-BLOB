DECLARE
  l_blob BLOB;
BEGIN

--Use Loop here for multiple files

  l_blob := APEX_WEB_SERVICE.MAKE_REST_REQUEST_B(
    p_url => 'https://example.com/image.jpg',
    p_http_method => 'GET'
  );

  INSERT INTO my_images (image_name, image_blob)
  VALUES ('image.jpg', l_blob);

  COMMIT;
END;

kpse.set_program_name("luatex")

local zip       = require "zip"
local domobject = require "luaxml-domobject"

local M          = {}
local EpubReader = {}

EpubReader.__index = EpubReader

function M.load(filename)
  t = setmetatable({}, EpubReader)
  status, msg = t:load(filename)
  if not status then return nil, msg end
  return t
end

function EpubReader:check_mimetype()
  local mimetype, msg = self:read_file("mimetype") 
  if not mimetype then return nil, "Cannot detect mimetype" end
  if mimetype ~= "application/epub+zip" then return nil, "Wrong mimetype: " .. mimetype end
  return true
end

function EpubReader:load_container()
  local container = self:read_xml_file("META-INF/container.xml")
  if not container then return nil, "Cannot read metadata" end
  self.container = container
  return true
end


function EpubReader:find_opf_file()
  local container = self.container
  local opf_path
  -- find path of the OPF data in the DOM object of container.xml
  for _, rootfile in ipairs(container:query_selector("rootfile")) do
    local path, media_type = rootfile:get_attribute("full-path"), rootfile:get_attribute("media-type")
    if media_type == "application/oebps-package+xml" then opf_path = path end
  end
  if not opf_path then return nil, "Cannot find the OPF file" end
  return opf_path
end

function EpubReader:load_opf_file()
  local opf_path  = self:find_opf_file()
  if not opf_path then return nil, msg end
  self.opf_path = opf_path
  self.opf = self:read_xml_file(opf_path)
  if not self.opf then return nil, "Cannot read the OPF file" end
  return true
end


function EpubReader.load(self, filename)
  -- open Epub file, validate basic metadata and load the opf file
  self.filename = filename
  self.zip_file, msg = zip.open(filename)
  if not self.zip_file then return nil, msg end
  -- check correct mimetype
  local status, msg = self:check_mimetype()
  if not status then return nil, msg end
  -- load container
  local status, msg = self:load_container()
  if not status then return nil, msg end
  -- load OPF file
  local status, msg = self:load_opf_file()
  if not status then return nil, msg end
  return true
end

function EpubReader.read_file(self, path)
  local path = path or ""
  local zip_file = self.zip_file
  local f = zip_file:open(path)
  if not f then
    return nil, "Cannot find file in the Epub file: ".. path
  end
  return f:read("*all")
end

function EpubReader.read_xml_file(self, path)
  local text, msg = self:read_file(path)
  if not text then return nil, msg end
  local dom = domobject.parse(text)
  if not dom then
    return nil, "Error in parsing XML file: " .. path
  end
  return dom
end

local filename = arg[1]
if not filename then
  print("Usage: epubreader filename.epub")
  os.exit()
end

local epub, msg = M.load(filename)

if not epub then 
  print("Cannot load epub file " .. filename)
  print(msg)
end

for _, item in ipairs(epub.opf:query_selector("manifest item")) do
  print(item:get_attribute("id"), item:get_attribute("href"), item:get_attribute("media-type"))
end

-- return EpubReader
return M

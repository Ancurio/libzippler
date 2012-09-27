

[CCode (cheader_filename = "ioapi.h")]
namespace IOApi
{
	[CCode (cprefix = "ZLIB_FILEFUNC_SEEK_", cname = "int")]
	public enum SeekType
	{
		CUR,
		END,
		SET
	}

	[Flags]
	[CCode (cprefix = "ZLIB_FILEFUNC_MODE_", cname = "int")]
	public enum Mode
	{
		READ,
		WRITE,

		[CCode (cname = "ZLIB_FILEFUNC_MODE_READWRITEFILTER")]
		READ_WRITE,

		EXISTING,
		CREATE
	}

	[CCode (cname = "open_file_func", has_target = false)]
	public delegate void* OpenFileFunc(void* user_data, string filename, Mode mode);

	[CCode (cname = "read_file_func", has_target = false)]
	public delegate ulong ReadFileFunc(void* user_data, void* stream, void* buffer, ulong size);

	[CCode (cname = "write_file_func", has_target = false)]
	public delegate ulong WriteFileFunc(void* user_data, void* stream, void* buffer, ulong size);

	[CCode (cname = "close_file_func", has_target = false)]
	public delegate bool CloseFileFunc(void* user_data, void* stream);

	[CCode (cname = "testerror_file_func", has_target = false)]
	public delegate bool TestErrorFileFunc(void* user_data, void* stream);

	[CCode (cname = "tell_file_func", has_target = false)]
	public delegate long TellFileFunc(void* user_data, void* stream);

	[CCode (cname = "seek_file_func", has_target = false)]
	public delegate long SeekFileFunc(void* user_data, void* stream, ulong offset, SeekType type);

	[CCode (cname = "zlib_filefunc_def")]
	public struct FileFuncVector
	{
		[CCode (cname = "zopen_file")]
		OpenFileFunc open;

		[CCode (cname = "zread_file")]
		ReadFileFunc read;

		[CCode (cname = "zwrite_file")]
		WriteFileFunc write;

		[CCode (cname = "ztell_file")]
		TellFileFunc tell;

		[CCode (cname = "zseek_file")]
		SeekFileFunc seek;

		[CCode (cname = "zclose_file")]
		CloseFileFunc close;

		[CCode (cname = "zerror_file")]
		TestErrorFileFunc test_error;

		[CCode (cname = "opaque")]
		void* user_data;
	}
}

[CCode (cheader_filename = "zip.h")]
namespace Zip
{
	[CCode (cname = "tm_zip")]
	public struct DateTime
	{
		[CCode (cname = "tm_sec")]
		uint second;
		[CCode (cname = "tm_min")]
		uint minute;
		[CCode (cname = "tm_hour")]
		uint hour;
		[CCode (cname = "tm_mday")]
		uint day;
		[CCode (cname = "tm_mon")]
		uint month;
		[CCode (cname = "tm_year")]
		uint year;
	}

	[CCode (cname = "zip_fileinfo")]
	public struct FileInfo
	{
		[CCode (cname = "tmz_date")]
		DateTime date_time;
		[CCode (cname = "dosDate")]
		ulong dos_date;
		ulong internal_fa;
		ulong external_fa;
	}

	[CCode (cname = "int")]
	public enum AppendMode
	{
		[CCode (cname = "APPEND_STATUS_CREATE")]
		CREATE,

		[CCode (cname = "APPEND_STATUS_CREATEAFTER")]
		CREATE_AFTER,

		[CCode (cname = "APPEND_STATUS_ADDINZIP")]
		ADD_IN_ZIP
	}

	[SimpleType]
	[CCode (cname = "zipFile")]
	public struct File
	{
		[CCode (cname = "zipOpen")]
		public File(string filename, AppendMode mode);

		[CCode (cname = "zipOpen2")]
		public File.with_vector(string filename,
		                        AppendMode mode,
		                        string? global_comment,
		                        IOApi.FileFuncVector vector);

		[CCode (cname = "zipOpenNewFileInZip")]
		public int open_new_file(string filename,
		                         FileInfo info,
		                         uint8[]? local_extrafield,
		                         uint8[]? global_extrafield,
		                         string? comment,
		                         int method,
		                         int level);

		[CCode (cname = "zipOpenNewFileInZip2")]
		public int open_new_file_raw(string filename,
		                             FileInfo info,
		                             uint8[]? local_extrafield,
		                             uint8[]? global_extrafield,
		                             string? comment,
		                             int method,
		                             int level,
		                             bool raw = true);

		[CCode (cname = "zipWriteInFileInZip")]
		public int write_to_file(uint8[] data);

		[CCode (cname = "zipCloseFileInZip")]
		public int close_file();

		[CCode (cname = "zipCloseFileInZipRaw")]
		public int close_file_raw(ulong uncompressed_size,
		                          ulong crc32);

		[CCode (cname = "zipClose")]
		public int close(string global_comment);
	}
}


[CCode (cheader_filename="unzip.h")]
namespace Unzip
{
	[CCode (cname = "int")]
	public enum ReturnCode
	{
		[CCode (cname = "UNZ_OK")]
		OK,

		[CCode (cname = "UNZ_END_OF_LIST_OF_FILE")]
		END_OF_FILE_LIST,

		[CCode (cname = "UNZ_ERRNO")]
		ERRNO,

		[CCode (cname = "UNZ_EOF")]
		EOF,

		[CCode (cname = "UNZ_PARAMERROR")]
		PARAM_ERROR,

		[CCode (cname = "UNZ_BADZIPFILE")]
		BAD_ZIPFILE,

		[CCode (cname = "UNZ_INTERNALERROR")]
		INTERNAL_ERROR,

		[CCode (cname = "UNZ_CRCERROR")]
		CRC_ERROR
	}

	[CCode (cname = "int")]
	public enum CaseSensitivity
	{
		[CCode (cname = "0")]
		OS_DEFAULT,

		[CCode (cname = "1")]
		SENSITIVE,

		[CCode (cname = "2")]
		INSENSITIVE
	}

	[CCode (cname = "unzStringFileNameCompare")]
	public static bool compare_filenames(string filename1,
	                                     string filename2,
	                                     CaseSensitivity sens);

	[SimpleType]
	[CCode (cname = "unzFile")]
	public struct File
	{
		[CCode (cname = "unzOpen")]
		public File(string filename);

		[CCode (cname = "unzOpen2")]
		public File.with_vector(string filename,
		                        IOApi.FileFuncVector vector);

		[CCode (cname = "unzClose")]
		public int close();

		[CCode (cname = "unzGetGlobalInfo")]
		public ReturnCode get_global_info(out GlobalInfo info);

		[CCode (cname = "unzGetGlobalComment")]
		public int get_global_comment(char[] buffer);

		[CCode (cname = "unzGoToFirstFile")]
		public ReturnCode go_to_first_file();

		[CCode (cname = "unzGoToNextFile")]
		public ReturnCode go_to_next_file();

		[CCode (cname = "unzLocateFile")]
		public int go_to_file(string file_name,
		                      CaseSensitivity case_sensitive = CaseSensitivity.OS_DEFAULT);

		[CCode (cname = "unzGetCurrentFileInfo")]
		public int get_current_file_info(out FileInfo info,
		                                 char[]? file_name = null,
		                                 uint8[]? extra_field = null,
		                                 char[]? file_comment = null);

		[CCode (cname = "unzGetFilePos")]
		public int get_current_file_position(out FilePosition pos);

		[CCode (cname = "unzGoToFilePos")]
		public int go_to_file_position(FilePosition pos);

		[CCode (cname = "unzOpenCurrentFile")]
		public int open_current_file();

		[CCode (cname = "unzOpenCurrentFilePassword")]
		public int open_current_file_password(string password);

		[CCode (cname = "unzOpenCurrentFile2")]
		public int open_current_file_raw(out int method,
		                                 out int level,
		                                 bool raw = true);

		[CCode (cname = "unzOpenCurrentFile3")]
		public int open_current_file_raw_password(out int method,
		                                          out int level,
		                                          bool raw = true,
		                                          string password);

		[CCode (cname = "unzReadCurrentFile")]
		public int read_current_file(uint8[] buffer);

		[CCode (cname = "unzCloseCurrentFile")]
		public int close_current_file();
	}

	[CCode (cname = "unz_global_info")]
	public struct GlobalInfo
	{
		[CCode (cname = "number_entry")]
		ulong entry_count;

		[CCode (cname = "size_comment")]
		ulong comment_size;
	}

	[CCode (cname = "tm_unz")]
	public struct DateTime
	{
		[CCode (cname = "tm_sec")]
		int second;
		[CCode (cname = "tm_min")]
		int minute;
		[CCode (cname = "tm_hour")]
		int hour;
		[CCode (cname = "tm_mday")]
		int day;
		[CCode (cname = "tm_mon")]
		int month;
		[CCode (cname = "tm_year")]
		int year;
	}

	[CCode (cname = "unz_file_info")]
	public struct FileInfo
	{
		ulong version;

		[CCode (cname = "version_needed")]
		ulong needed_version;

		[CCode (cname = "flag")]
		ulong flags;

		ulong compression_method;

		[CCode (cname = "dosDate")]
		ulong dos_date;

		ulong crc;

		ulong compressed_size;

		ulong uncompressed_size;

		[CCode (cname = "size_filename")]
		ulong filename_size;

		[CCode (cname = "size_file_extra")]
		ulong file_extra_size;

		[CCode (cname = "size_file_comment")]
		ulong file_comment_size;

		[CCode (cname = "disk_num_start")]
		ulong disk_number_start;

		ulong internal_fa;

		ulong external_fa;

		[CCode (cname = "tmu_date")]
		DateTime date_time;
	}

	[CCode (cname = "unz_file_pos")]
	public struct FilePosition
	{
		[CCode (cname = "pos_in_zip_directory")]
		ulong position;

		[CCode (cname = "num_of_file")]
		ulong nth_file;
	}
}


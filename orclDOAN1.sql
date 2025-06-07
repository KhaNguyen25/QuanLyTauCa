-- IV. CREATE TRIGGER
-- Kiem tra vi pham vung bien
CREATE OR REPLACE TRIGGER TRG_check_VI_PHAM
AFTER INSERT ON LOG_HAI_TRINH
FOR EACH ROW
DECLARE
    v_poly SDO_GEOMETRY;
    v_Count NUMBER;
BEGIN
    SELECT nt.ViTri
    INTO v_poly
    FROM CHUYEN_DANH_BAT cdb
    JOIN NGU_TRUONG nt ON nt.MaNguTruong = cdb.MaNguTruong
    WHERE cdb.MaChuyenDanhBat = :NEW.MaChuyenDanhBat;

    SELECT count(*)
    INTO v_Count
    FROM VI_PHAM vp
    WHERE vp.MaChuyenDanhBat = :NEW.MaChuyenDanhBat;

    IF SDO_CONTAINS(v_poly, :NEW.ViTri) = 'FALSE' AND v_Count = 0 THEN
        insert_VI_PHAM(:NEW.MaChuyenDanhBat, SDO_UTIL.TO_WKTGEOMETRY(:NEW.ViTri), 'Vi pham vung bien');
    END IF;

EXCEPTION
    WHEN OTHERS THEN
    RAISE_APPLICATION_ERROR(-20001,
            'Error in TRG_check_VI_PHAM: ' || SQLERRM);
END;
/
--DE xuat chinh sua
CREATE OR REPLACE TRIGGER TRG_check_VI_PHAM
AFTER INSERT ON LOG_HAI_TRINH
FOR EACH ROW
DECLARE
    v_poly SDO_GEOMETRY;
    v_Count NUMBER;
    v_contains  NUMBER := 0;  -- khởi tạo mặc định
BEGIN
    -- Lấy vùng ngư trường
    SELECT nt.ViTri
    INTO v_poly
    FROM CHUYEN_DANH_BAT cdb
    JOIN NGU_TRUONG nt ON nt.MaNguTruong = cdb.MaNguTruong
    WHERE cdb.MaChuyenDanhBat = :NEW.MaChuyenDanhBat;

    -- Đếm số vi phạm hiện tại
    SELECT count(*)
    INTO v_Count
    FROM VI_PHAM vp
    WHERE vp.MaChuyenDanhBat = :NEW.MaChuyenDanhBat;

    -- Kiểm tra SDO_CONTAINS an toàn
    BEGIN
        IF v_poly IS NOT NULL AND :NEW.ViTri IS NOT NULL THEN
            SELECT SDO_CONTAINS(v_poly, :NEW.ViTri)
            INTO v_contains
            FROM DUAL;
            -- Nếu NULL thì gán 0
            IF v_contains IS NULL THEN
                v_contains := 0;
            END IF;
        ELSE
            v_contains := 0;
        END IF;

    EXCEPTION
        WHEN OTHERS THEN
            RAISE_APPLICATION_ERROR(-200065,
                'Error in TRG_check_VI_PHAM: SDO_CONTAINS, ' || SQLERRM);
    END;

    IF v_contains = 0 AND v_Count = 0 THEN
        insert_VI_PHAM(:NEW.MaChuyenDanhBat, SDO_UTIL.TO_WKTGEOMETRY(:NEW.ViTri), 'Vi pham vung bien');
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        RAISE_APPLICATION_ERROR(-20001,
            'Error in TRG_check_VI_PHAM: ' || SQLERRM);
END;
/
--checked

-- CAP NHAT SAN LUONG CHUYEN DANH BAT
CREATE OR REPLACE TRIGGER TRG_update_weight
AFTER INSERT ON DANHBAT_THUYSAN
FOR EACH ROW
BEGIN
    UPDATE ME_CA
    SET KhoiLuongMeCa = KhoiLuongMeCa + :NEW.KhoiLuong
    WHERE MaMeCa = :NEW.MaMeCa AND MaChuyenDanhBat = :NEW.MaChuyenDanhBat;

    UPDATE CHUYEN_DANH_BAT
    SET TongKhoiLuong = TongKhoiLuong + :NEW.KhoiLuong
    WHERE MaChuyenDanhBat = :NEW.MaChuyenDanhBat;

EXCEPTION
    WHEN OTHERS THEN
    RAISE_APPLICATION_ERROR(-20002,
            'Error in TRG_update_weight: ' || SQLERRM);
END;
/

--check ThoiGianThaLuoi va ThoiGianKeoLuoi
CREATE OR REPLACE TRIGGER TRG_check_date_ME_CA
BEFORE INSERT OR UPDATE ON ME_CA
FOR EACH ROW
DECLARE
    v_NgayXuatBen date;
    v_MaChuyenDanhBat ME_CA.MaChuyenDanhBat%TYPE;
BEGIN
    v_MaChuyenDanhBat := :NEW.MaChuyenDanhBat;
    
    SELECT NgayXuatBen
    INTO v_NgayXuatBen
    FROM CHUYEN_DANH_BAT
    WHERE MaChuyenDanhBat = v_MaChuyenDanhBat;

    IF :NEW.ThoiGianThaLuoi < v_NgayXuatBen OR :NEW.ThoiGianThaLuoi > SYSDATE THEN
        RAISE_APPLICATION_ERROR(-number, 'Error in TRG_check_date_ME_CA: ThoiGianThaLuoi khong dung');
    ELSIF :NEW.ThoiGianKeoLuoi < :NEW.ThoiGianThaLuoi OR :NEW.ThoiGianKeoLuoi > SYSDATE THEN
        RAISE_APPLICATION_ERROR(-number, 'Error in TRG_check_date_ME_CA: ThoiGianKeoLuoi khong dung');
    END IF;

EXCEPTION
    WHEN OTHERS THEN
    RAISE_APPLICATION_ERROR(-20002,
            'Error in TRG_check_date_ME_CA: ' || SQLERRM);
END;
/
--checked

-- V. CREATE PROCEDURE

-- PROCEDURE LAY DU LIEU
-- Lay danh sach tat ca TAU_CA
CREATE OR REPLACE PROCEDURE get_ships_list(
    p_cursor OUT SYS_REFCURSOR
)
IS
BEGIN
    OPEN p_cursor FOR
        SELECT MaTauCa, SoDangKy
        FROM TAU_CA;

EXCEPTION
    WHEN OTHERS THEN
    RAISE_APPLICATION_ERROR(-20003,
            'Error in get_ships_list: ' || SQLERRM);
END;
/
--checked

-- Lay danh sach TAU_CA cua CHU_TAU
CREATE OR REPLACE PROCEDURE get_owner_ships_list(
    p_cursor OUT SYS_REFCURSOR,
    p_MaChuTau   CHU_TAU.MaChuTau%TYPE
)
IS
BEGIN
    OPEN p_cursor FOR
        SELECT MaTauCa, SoDangKy
        FROM TAU_CA t 
        WHERE t.MaChuTau = p_MaChuTau;

EXCEPTION
    WHEN OTHERS THEN
    RAISE_APPLICATION_ERROR(-20004,
            'Error in get_owner_ships_list: ' || SQLERRM);
END;
/
--checked

-- Lay danh sach CHU_TAU cho duyet
CREATE OR REPLACE PROCEDURE get_owners_pending_list(
    chu_tau_cursor OUT SYS_REFCURSOR
)
IS
BEGIN
    OPEN chu_tau_cursor FOR
        SELECT MaChuTau, HoTen, CCCD, TrangThaiDuyet
        FROM CHU_TAU ct
        WHERE ct.TrangThaiDuyet = 'DANG CHO';

EXCEPTION
    WHEN OTHERS THEN
    RAISE_APPLICATION_ERROR(-20005,
            'Error in get_owners_pending_list: ' || SQLERRM);
END;
/
--checked

-- Lay danh sach TAU_CA cho duyet
CREATE OR REPLACE PROCEDURE get_ships_pending_list(
    p_cursor OUT SYS_REFCURSOR
)
IS 
BEGIN
    OPEN p_cursor FOR
        SELECT MaTauCa, SoDangKy, TrangThaiDuyet
        FROM TAU_CA tc
        WHERE tc.TrangThaiDuyet = 'DANG CHO';

EXCEPTION
    WHEN OTHERS THEN
    RAISE_APPLICATION_ERROR(-20006,
            'Error in get_ships_pending_list: ' || SQLERRM);
END;
/
--checked

-- Lay thong tin chi tiet CHU_TAU
CREATE OR REPLACE PROCEDURE get_owner_info(
    chu_tau_cursor OUT SYS_REFCURSOR,
    p_MaChuTau      CHU_TAU.MaChuTau%TYPE
)
IS
BEGIN
    OPEN chu_tau_cursor FOR
        SELECT *
        FROM CHU_TAU ct
        WHERE ct.MaChuTau = p_MaChuTau;

EXCEPTION
    WHEN OTHERS THEN
    RAISE_APPLICATION_ERROR(-20007,
            'Error in get_owner_info: ' || SQLERRM);
END;
/
--checked

-- Lay thong tin chi tiet TAU_CA
CREATE OR REPLACE PROCEDURE get_ship_info(
    tau_ca_cursor OUT SYS_REFCURSOR,
    p_MaTauCa      TAU_CA.MaTauCa%TYPE
)
IS
BEGIN
    OPEN tau_ca_cursor FOR
        SELECT * 
        FROM TAU_CA tc
        WHERE tc.MaTauCa = p_MaTauCa;

EXCEPTION
    WHEN OTHERS THEN
    RAISE_APPLICATION_ERROR(-20008,
            'Error in get_ship_info: ' || SQLERRM);
END;
/
--checked

-- Lay danh sach TAU_CA va trang thai hoat dong TAU_CA cua CHU_TAU
CREATE OR REPLACE PROCEDURE get_owner_ships_list_and_working_status(
    tau_ca_cursor OUT SYS_REFCURSOR,
    p_MaChuTau        TAU_CA.MaChuTau%TYPE
)
IS
BEGIN
    OPEN tau_ca_cursor FOR
        SELECT tc.MaTauCa, tc.SoDangKy, tc.TrangThaiHoatDong 
        FROM TAU_CA tc 
        WHERE tc.MaChuTau = p_MaChuTau;

EXCEPTION
    WHEN OTHERS THEN
    RAISE_APPLICATION_ERROR(-20009,
            'Error in get_owner_ships_list_and_working_status: ' || SQLERRM);
END;
/
--checked

-- Lay thong tin CHUYEN_DANH_BAT
CREATE OR REPLACE PROCEDURE get_voyages_info(
    cdb_cursor OUT SYS_REFCURSOR,
    p_MaChuyenDanhBat   CHUYEN_DANH_BAT.MaChuyenDanhBat%TYPE
)
IS
BEGIN
    OPEN cdb_cursor FOR
        SELECT *
        FROM CHUYEN_DANH_BAT cdb
        WHERE cdb.MaChuyenDanhBat = p_MaChuyenDanhBat;

EXCEPTION
    WHEN OTHERS THEN
    RAISE_APPLICATION_ERROR(-20010,
            'Error in get_voyages_info: ' || SQLERRM);
END;
/
--checked

-- Lay danh sach CHUYEN_DANH_BAT cho duyet
CREATE OR REPLACE PROCEDURE get_voyages_pending_list(
    cdb_cursor OUT SYS_REFCURSOR
)
IS
BEGIN
    OPEN cdb_cursor FOR
        SELECT cdb.MaTauCa, cdb.MaChuyenDanhBat, cdb.TrangThaiDuyet
        FROM CHUYEN_DANH_BAT cdb
        WHERE cdb.TrangThaiDuyet = 'DANG CHO';

EXCEPTION
    WHEN OTHERS THEN
    RAISE_APPLICATION_ERROR(-20011,
            'Error in get_voyages_pending_list: ' || SQLERRM);
END;
/
--checked

-- Lay danh sach CHUYEN_DANH_BAT cua TAU_CA
CREATE OR REPLACE PROCEDURE get_ship_voyages_list(
    cdb_cursor OUT SYS_REFCURSOR,
    p_MaTauCa   CHUYEN_DANH_BAT.MaTauCa%tTYPE
)
IS
BEGIN
    OPEN cdb_cursor FOR
        SELECT cdb.MaChuyenDanhBat, cdb.TrangThaiHoatDong 
        FROM CHUYEN_DANH_BAT cdb
        WHERE cdb.MaTauCa = p_MaTauCa;

EXCEPTION
    WHEN OTHERS THEN
    RAISE_APPLICATION_ERROR(-20012,
            'Error in get_ship_voyages_list: ' || SQLERRM);
END;
/
--checked

-- Lay danh sach tat ca TAU_CA DANG HOAT DONG
CREATE OR REPLACE PROCEDURE get_working_ships_list(
    p_cursor OUT SYS_REFCURSOR
)
IS
BEGIN
    OPEN p_cursor FOR
        SELECT * FROM TAU_CA t WHERE t.TRANGTHAIHOATDONG ='DANG HOAT DONG';

EXCEPTION
    WHEN OTHERS THEN
    RAISE_APPLICATION_ERROR(-20013,
            'Error in get_working_ships_list: ' || SQLERRM);
END;
/
--xem lai

-- Lay danh sach cac NGU_TRUONG
CREATE OR REPLACE PROCEDURE get_fishery_list(
    ngu_truong_cursor OUT SYS_REFCURSOR
)
IS
BEGIN
    OPEN ngu_truong_cursor FOR
        SELECT ng.MaNguTruong, ng.TenNguTruong 
        FROM NGU_TRUONG ng;

EXCEPTION
    WHEN OTHERS THEN
    RAISE_APPLICATION_ERROR(-20014,
            'Error in get_fishery_list: ' || SQLERRM);
END;
/
--checked

-- Lay thong tin THOI_TIET moi nhat
CREATE OR REPLACE PROCEDURE get_newest_weather_info(
    weather_cursor OUT SYS_REFCURSOR
)
IS
BEGIN
    OPEN weather_cursor FOR
        SELECT *
        FROM (
            SELECT *
            FROM THOI_TIET
            ORDER BY ThoiGianDuBao DESC
        )
        WHERE ROWNUM = 1;

EXCEPTION
    WHEN OTHERS THEN
    RAISE_APPLICATION_ERROR(-20015,
            'Error in get_newest_weather_info: ' || SQLERRM);
END;
/
--checked

-- Lay danh sach BAO
CREATE OR REPLACE PROCEDURE get_storm_list(
    bao_cursor OUT SYS_REFCURSOR
)
IS
BEGIN
    OPEN bao_cursor FOR
        SELECT *
        FROM BAO b;

EXCEPTION
    WHEN OTHERS THEN
    RAISE_APPLICATION_ERROR(-20016,
            'Error in get_storm_list: ' || SQLERRM);
END;
/
--checked

-- Lay thong tin chi tiet BAO
CREATE OR REPLACE PROCEDURE get_storm_info(
    bao_cursor OUT SYS_REFCURSOR,
    p_MaBao        LOG_DUONG_DI_BAOAO.MaBao%TYPE
)
IS
BEGIN
    OPEN bao_cursor FOR
        SELECT lddb.MaLogDuongDi, lddb.ThoiGian, DBMS_LOB.SUBSTR(SDO_UTIL.TO_WKTGEOMETRY(lddb.ViTri), 4000, 1) as ViTriWKT, lddb.MucDo
        FROM LOG_DUONG_DI_BAO lddb
        JOIN BAO b ON b.MaBao = lddb.MaBao
        WHERE b.MABAO = p_MaBao
        ORDER BY MaLogDuongDi ASC;

EXCEPTION
    WHEN OTHERS THEN
    RAISE_APPLICATION_ERROR(-20017,
            'Error in get_storm_info: ' || SQLERRM);
END;
/

-- PROCEDURE XU LY
-- Tao admin
CREATE OR REPLACE PROCEDURE insert_ADMIN(
    p_USERNAME      APP_USER.USERNAME%TYPE,
    p_PASSWORD      APP_USER.PASSWORD%TYPE,
    p_HoTen         ADMIN.HoTen%TYPE,
    p_CoQuan        ADMIN.CoQuan%TYPE,
    p_CCCD          ADMIN.CCCD%TYPE
)
IS
    p_MaAdmin       ADMIN.MaAdmin%TYPE;
BEGIN
    INSERT INTO APP_USER(USERNAME, PASSWORD, ROLE)
    VALUES(p_USERNAME, p_PASSWORD, 'ADMIN');

    SELECT USER_ID
    INTO p_MaAdmin
    FROM APP_USER
    WHERE USERNAME = p_USERNAME;

    INSERT INTO ADMIN(MaAdmin, HoTen, CoQuan, CCCD)
    VALUES(p_MaAdmin, p_HoTen, p_CoQuan, p_CCCD);

EXCEPTION
    WHEN OTHERS THEN
    RAISE_APPLICATION_ERROR(-20018,
            'Error in insert_ADMIN: ' || SQLERRM);
END;
/
--checked

--1. THONG TIN DANG KY 

-- DANG KY THONG TIN CHU_TAU
-- Tao CHU_TAU
CREATE OR REPLACE PROCEDURE insert_CHU_TAU(
    p_USERNAME      APP_USER.USERNAME%TYPE,
    p_PASSWORD      APP_USER.PASSWORD%TYPE,
    p_HoTen         CHU_TAU.HoTen%TYPE,
    p_SDT           CHU_TAU.SDT%TYPE,
    p_DiaChi        CHU_TAU.DiaChi%TYPE,
    p_CCCD          CHU_TAU.CCCD%TYPE
)
IS
    p_MaChuTau      CHU_TAU.MaChuTau%TYPE;
BEGIN
    INSERT INTO APP_USER(USERNAME, PASSWORD)
    VALUES(p_USERNAME, p_PASSWORD);

    SELECT USER_ID
    INTO p_MaChuTau
    FROM APP_USER
    WHERE USERNAME = p_USERNAME;

    INSERT INTO CHU_TAU(MaChuTau, HoTen, SDT, DiaChi, CCCD)
    VALUES(p_MaChuTau, p_HoTen, p_SDT, NULLIF(TRIM(p_DiaChi), ''), p_CCCD);

EXCEPTION
    WHEN OTHERS THEN
        RAISE_APPLICATION_ERROR(-20019,
            'Error in insert_CHU_TAU: ' || SQLERRM);
END;
/
--checked

-- DANG KY THONG TIN TAU_CA
-- Insert NGHE
CREATE OR REPLACE PROCEDURE insert_NGHE(
    p_TenNghe       NGHE.TenNghe%TYPE
)
IS
BEGIN
    INSERT INTO NGHE(TenNghe)
    VALUES (p_TenNghe);

EXCEPTION
    WHEN OTHERS THEN
        RAISE_APPLICATION_ERROR(-20020,
            'Error in insert_NGHE: ' || SQLERRM);
END;

-- Insert TAU_CA
CREATE OR REPLACE PROCEDURE insert_TAU_CA(
    p_SoDangKy           TAU_CA.SoDangKy%TYPE,
    p_ChieuDai           TAU_CA.ChieuDai%TYPE,
    p_CongSuat           TAU_CA.CongSuat%TYPE,
    p_NamDongTau         TAU_CA.NamDongTau%TYPE,
    p_MaChuTau           TAU_CA.MaChuTau%TYPE,
    p_MaNgheChinh        TAU_CA.MaNgheChinh%TYPE
)
IS
    p_TrangThaiDuyetChuTau  CHUTAU.TrangThaiDuyet%TYPE;
BEGIN
    SELECT TrangThaiDuyet
    INTO p_TrangThaiDuyetChuTau
    FROM CHU_TAU
    WHERE MaChuTau = p_MaChuTau;

    IF p_TrangThaiDuyetChuTau = 'DA DUYET' THEN
        INSERT INTO TAU_CA(SoDangKy, ChieuDai, CongSuat, NamDongTau, MaChuTau, MaNgheChinh)
        VALUES (p_SoDangKy, p_ChieuDai, p_CongSuat, p_NamDongTau, p_MaChuTau, p_MaNgheChinh);
    ELSE
        RAISE_APPLICATION_ERROR(-20021, 'Error in insert_TAU_CA: HO SO CHU TAU CHUA DUOC DUYET');
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        RAISE_APPLICATION_ERROR(-20022,
            'Error in insert_TAU_CA: ' || SQLERRM);
END;
/
--checked

-- Insert NGHE cho TAU_CA
CREATE OR REPLACE PROCEDURE insert_TAU_NGHE(
    p_MaTauCa            TAU_NGHE.MaTauCa%TYPE,
    p_MaNghe             TAU_NGHE.MaNghe%TYPE,
    p_VungHoatDong       TAU_NGHE.VungHoatDong%TYPE
)
IS
BEGIN
    INSERT INTO TAU_NGHE(MaTauCa, MaNghe, VungHoatDong)
    VALUES (p_MaTauCa, p_MaNghe, p_VungHoatDong);

EXCEPTION
    WHEN OTHERS THEN
        RAISE_APPLICATION_ERROR(-20023,
            'Error in insert_TAU_NGHE: ' || SQLERRM);
END;
/
--checked

-- DUYET THONG TIN CHU_TAU
-- Cap nhat trang thai duyet CHU_TAU
CREATE OR REPLACE PROCEDURE update_approval_status_CHU_TAU(
    p_TrangThaiDuyet    CHU_TAU.TrangThaiDuyet%TYPE,
    p_MaChuTau          CHU_TAU.MaChuTau%TYPE
)
IS
BEGIN
    UPDATE CHU_TAU
    SET TrangThaiDuyet = p_TrangThaiDuyet
    WHERE MaChuTau = p_MaChuTau;

EXCEPTION
    WHEN OTHERS THEN
        RAISE_APPLICATION_ERROR(-20024,
            'Error in update_approval_status_CHU_TAU: ' || SQLERRM);
END;
/
--checked

-- DUYET THONG TIN TAU_CA
-- Cap nhat trang thai duyet TAU_CA
CREATE OR REPLACE PROCEDURE update_approval_status_TAU_CA(
    p_TrangThaiDuyet    TAU_CA.TrangThaiDuyet%TYPE,
    p_MaTauCa           TAU_CA.MaTauCa%TYPE
)
IS
BEGIN
    UPDATE TAU_CA
    SET TrangThaiDuyet = p_TrangThaiDuyet
    WHERE MaTauCa = p_MaTauCa;

EXCEPTION
    WHEN OTHERS THEN
        RAISE_APPLICATION_ERROR(-20025,
            'Error in update_approval_status_TAU_CA: ' || SQLERRM);
END;
/
--checked

-- CAP NHAT THONG TIN CHU_TAU
-- Update CHU_TAU
CREATE OR REPLACE PROCEDURE update_info_CHU_TAU(
    p_MaChuTau        CHU_TAU.MaChuTau%TYPE,
    p_HoTen           CHU_TAU.HoTen%TYPE,
    p_SDT             CHU_TAU.SDT%TYPE,
    p_DiaChi          CHU_TAU.DiaChi%TYPE,
    p_CCCD            CHU_TAU.CCCD%TYPE
)
IS
BEGIN
    UPDATE CHU_TAU
    SET HoTen = p_HoTen,
        SDT = p_SDT,
        DiaChi = p_DiaChi,
        CCCD = p_CCCD,
        TrangThaiDuyet = 'DANG CHO'
    WHERE MaChuTau = p_MaChuTau;
    
EXCEPTION
    WHEN OTHERS THEN
        RAISE_APPLICATION_ERROR(-20026,
            'Error in update_info_CHU_TAU: ' || SQLERRM);
END;
/
--checked

-- CAP NHAT THONG TIN TAU_CA
-- Update TAU_CA
CREATE OR REPLACE PROCEDURE update_info_TAU_CA(
    p_MaTauCa            TAU_CA.MaTauCa%TYPE,
    p_SoDangKy           TAU_CA.SoDangKy%TYPE,
    p_ChieuDai           TAU_CA.ChieuDai%TYPE,
    p_CongSuat           TAU_CA.CongSuat%TYPE,
    p_NamDongTau         TAU_CA.NamDongTau%TYPE,
    p_MaNgheChinh        TAU_CA.MaNgheChinh%TYPE
)
IS
BEGIN
    UPDATE TAU_CA
    SET SoDangKy = p_SoDangKy,
        ChieuDai = p_ChieuDai,
        CongSuat = p_CongSuat,
        NamDongTau = p_NamDongTau,
        TrangThaiDuyet = 'DANG CHO',
        MaNgheChinh = p_MaNgheChinh
    WHERE MaTauCa = p_MaTauCa;
    
EXCEPTION
    WHEN OTHERS THEN
        RAISE_APPLICATION_ERROR(-20027,
            'Error in update_info_TAU_CA: ' || SQLERRM);
END;
/
--checked

-- THEO DOI TRANG THAI DUYET CHU_TAU
-- Lay trang thai duyet CHU_TAU
CREATE OR REPLACE PROCEDURE get_approval_status_CHU_TAU(
    chu_tau_cursor OUT SYS_REFCURSOR,
    p_MaChuTau         CHU_TAU.MaChuTau%TYPE
)
IS
BEGIN
    OPEN chu_tau_cursor FOR
        SELECT ct.TrangThaiDuyet
        FROM CHU_TAU ct
        WHERE ct.MaChuTau = p_MaChuTau;

EXCEPTION
    WHEN OTHERS THEN
        RAISE_APPLICATION_ERROR(-20028,
            'Error in get_approval_status_CHU_TAU: ' || SQLERRM);
END;
/
--checked

-- THEO DOI TRANG THAI DUYET TAU_CA
-- Lay danh sau TAU_CA va trang thai duyet TAU_CA cua CHU_TAU
CREATE OR REPLACE PROCEDURE get_approval_status_TAU_CA(
    tau_ca_cursor OUT SYS_REFCURSOR,
    p_MaChuTau        CHU_TAU.MaChuTau%TYPE
)
IS
BEGIN
    OPEN tau_ca_cursor FOR
        SELECT tc.MaTauCa, tc.SoDangKy, tc.TrangThaiDuyet
        FROM TAU_CA tc
        WHERE tc.MaChuTau = p_MaChuTau;

EXCEPTION
    WHEN OTHERS THEN
        RAISE_APPLICATION_ERROR(-20029,
            'Error in get_approval_status_TAU_CA: ' || SQLERRM);
END;
/
--checked

-- 2.HOAT DONG DANH BAT BAT

-- DANG KY THONG TIN CHUYEN DANH BAT
-- Tao CHUYEN_DANH_BAT
CREATE OR REPLACE PROCEDURE insert_CHUYEN_DANH_BAT(
    p_NgayXuatBen       CHUYEN_DANH_BAT.NgayXuatBen%TYPE,
    p_NgayCapBen       CHUYEN_DANH_BAT.NgayCapBen%TYPE,
    p_CangDi            CHUYEN_DANH_BAT.CangDi%TYPE,
    p_CangVe            CHUYEN_DANH_BAT.CangVe%TYPE,
    p_MaTauCa           CHUYEN_DANH_BAT.MaTauCa%TYPE,
    p_MaNguTruong       CHUYEN_DANH_BAT.MaNguTruong%TYPE
)
IS
    p_TrangThaiDuyetChuTau          CHU_TAU.TrangThaiDuyet%TYPE;
    p_TrangThaiDuyetTauCa           TAU_CA.TrangThaiDuyet%TYPE;
    p_TrangThaiHoatDongTauCa        TAU_CA.TrangThaiDuyet%TYPE;
    p_KtraSoLuongTau                BOOLEAN;
BEGIN
    SELECT ct.TrangThaiDuyet, tc.TrangThaiDuyet, tc.TrangThaiHoatDong
    INTO p_TrangThaiDuyetChuTau, p_TrangThaiDuyetTauCa, p_TrangThaiHoatDongTauCa
    FROM TAU_CA tc 
    JOIN CHU_TAU ct ON tc.MaChuTau = ct.MaChuTau
    WHERE tc.MaTauCa = p_MaTauCa;

    p_KtraSoLuongTau := Fn_kiem_tra_so_luong_tau(p_MaNguTruong);

    IF p_TrangThaiDuyetChuTau = 'DA DUYET' AND p_TrangThaiDuyetTauCa = 'DA DUYET' AND p_TrangThaiHoatDongTauCa = 'DANG CHO|CHUA DK' AND p_KtraSoLuongTau = TRUE THEN
        INSERT INTO CHUYEN_DANH_BAT(
            NgayXuatBen,
            NgayCapBen,
            CangDi,
            CangVe,
            MaTauCa,
            MaNguTruong
        )
        VALUES(
            p_NgayXuatBen,
            p_NgayCapBen,
            p_CangDi,
            p_CangVe,
            p_MaTauCa,
            p_MaNguTruong
        );

        UPDATE NGU_TRUONG
        SET SoLuongTauHienTai = SoLuongTauHienTai + 1
        WHERE MaNguTruong = p_MaNguTruong;

        UPDATE TAU_CA
        SET TrangThaiHoatDong = 'DANG CHO|DA DK'
        WHERE MaTauCa = p_MaTauCa;

    ELSIF p_TrangThaiHoatDongTauCa != 'DANG CHO|CHUA DK' THEN
        RAISE_APPLICATION_ERROR(-20030, 'Error in insert_CHUYEN_DANH_BAT: TAU DA DUOC DANG KY');
    ELSIF p_KtraSoLuongTau = FALSE THEN
        RAISE_APPLICATION_ERROR(-20031, 'Error in insert_CHUYEN_DANH_BAT: SO LUONG TAU O NGU TRUONG DAT TOI DA');
    ELSE
        RAISE_APPLICATION_ERROR(-20032, 'Error in insert_CHUYEN_DANH_BAT: HO SO CHU TAU HOAC HO SO TAU CA CHUA DUOC DUYET');
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        RAISE_APPLICATION_ERROR(-20033,
            'Error in insert_CHUYEN_DANH_BAT: ' || SQLERRM);
END;
/
--checked

-- DUYET THONG TIN CHUYEN DANH BAT
-- Cap nhat trang thai duyet CHUYEN_DANH_BAT
CREATE OR REPLACE PROCEDURE update_approval_status_CHUYEN_DANH_BAT(
    p_TrangThaiDuyet    CHUYEN_DANH_BAT.TrangThaiDuyet%TYPE,
    p_MaChuyenDanhBat   CHUYEN_DANH_BAT.MaChuyenDanhBat%TYPE
)
IS
    p_MaNguTruong    CHUYEN_DANH_BAT.MaNguTruong%TYPE;
    p_MaTauCa        CHUYEN_DANH_BAT.MaTauCa%TYPE;
BEGIN
    UPDATE CHUYEN_DANH_BAT
    SET TrangThaiDuyet = p_TrangThaiDuyet
    WHERE MaChuyenDanhBat = p_MaChuyenDanhBat;

    IF p_TrangThaiDuyet != 'DA DUYET' THEN
        SELECT MaTauCa, MaNguTruong
        INTO p_MaTauCa, p_MaNguTruong
        FROM CHUYEN_DANH_BAT
        WHERE MaChuyenDanhBat = p_MaChuyenDanhBat; 

        UPDATE TAU_CA
        SET TrangThaiHoatDong = 'DANG CHO|CHUA DK'
        WHERE MaTauCa = p_MaTauCa;

        UPDATE NGU_TRUONG
        SET SoLuongTauHienTai = SoLuongTauHienTai - 1
        WHERE MaNguTruong = p_MaNguTruong;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        RAISE_APPLICATION_ERROR(-20034,
            'Error in update_approval_status_CHUYEN_DANH_BAT: ' || SQLERRM);
END;
/
--checked

-- GIAM SAT DANH BAT
-- Lay thong tin vi tri moi nhat cua tat ca tau
CREATE OR REPLACE PROCEDURE get_newest_location_info_all(
    p_cursor OUT SYS_REFCURSOR
)
IS
BEGIN
    OPEN p_cursor FOR
        SELECT MaTauCa, ThoiGian, ViTriWKT, VanToc, HuongDiChuyen
        FROM (
            SELECT tc.MaTauCa, lht.ThoiGian,
                DBMS_LOB.SUBSTR(SDO_UTIL.TO_WKTGEOMETRY(lht.ViTri), 4000, 1) AS ViTriWKT,
                lht.VanToc, lht.HuongDiChuyen,
                ROW_NUMBER() OVER (
                PARTITION BY tc.MaTauCa
                ORDER BY lht.ThoiGian DESC
                ) AS rn
            FROM TAU_CA tc
            JOIN CHUYEN_DANH_BAT cdb ON cdb.MaTauCa = tc.MaTauCa
            JOIN LOG_HAI_TRINH lht ON lht.MaChuyenDanhBat = cdb.MaChuyenDanhBat
        ) sub
        WHERE sub.rn = 1;

EXCEPTION
    WHEN OTHERS THEN
        RAISE_APPLICATION_ERROR(-20035,
            'Error in get_newest_location_info_all: ' || SQLERRM);
END;
/
--checked

-- GIAM SAT TAU_CA TRONG DOI TAU
-- Lay thong tin vi tri moi nhat cua cac tau trong doi tau
CREATE OR REPLACE PROCEDURE get_newest_location_info_owner(
    p_cursor OUT SYS_REFCURSOR,
    p_MaChuTau      TAU_CA.MaChuTau%TYPE
)
IS
BEGIN
  OPEN p_cursor FOR
    SELECT MaTauCa, ThoiGian, ViTriWKT, VanToc, HuongDiChuyen
    FROM (
        SELECT tc.MaTauCa, lht.ThoiGian,
            DBMS_LOB.SUBSTR(SDO_UTIL.TO_WKTGEOMETRY(lht.ViTri), 4000, 1) AS ViTriWKT,
            lht.VanToc, lht.HuongDiChuyen,
            ROW_NUMBER() OVER (
            PARTITION BY tc.MaTauCa
            ORDER BY lht.ThoiGian DESC
            ) AS rn
        FROM TAU_CA tc
        JOIN CHUYEN_DANH_BAT cdb ON cdb.MaTauCa = tc.MaTauCa
        JOIN LOG_HAI_TRINH lht ON lht.MaChuyenDanhBat = cdb.MaChuyenDanhBat
        WHERE tc.MaChuTau = p_MaChuTau
    ) sub
    WHERE sub.rn = 1;

EXCEPTION
    WHEN OTHERS THEN
        RAISE_APPLICATION_ERROR(-20036,
            'Error in get_newest_location_info_owner: ' || SQLERRM);
END;
/
--checked

-- CAP NHAT TRANG THAI ROI / CAP CANG
-- Cap nhat trang thai roi cang
CREATE OR REPLACE PROCEDURE update_working_status_depart(
    p_MaTauCa   CHUYEN_DANH_BAT.MaTauCa%TYPE,
    p_CangDi    CHUYEN_DANH_BAT.CangDi%TYPE
)
IS
    p_MaChuyenDanhBat               CHUYEN_DANH_BAT.MaChuyenDanhBat%TYPE;
    p_TrangThaiHoatDongTauCa        TAU_CA.TrangThaiHoatDong%TYPE;
    p_TrangThaiDuyetCDB             CHUYEN_DANH_BAT.TrangThaiDuyet%TYPE;
BEGIN
    SELECT TrangThaiHoatDong
    INTO p_TrangThaiHoatDongTauCa
    FROM TAU_CA
    WHERE MaTauCa = p_MaTauCa;

    IF p_TrangThaiHoatDongTauCa = 'DANG CHO|CHUA DK' THEN
        RAISE_APPLICATION_ERROR(-20037, 'Error in update_working_status_depart: TAU CHUA DANG KY CHUYEN DANH BAT');
    ELSIF p_TrangThaiHoatDongTauCa = 'DANG HOAT DONG' THEN
        RAISE_APPLICATION_ERROR(-20038, 'Error in update_working_status_depart: TAU DANG HOAT DONG, KHONG THE DUNG CHUC NANG NAY');
    END IF;

    SELECT MaChuyenDanhBat
    INTO p_MaChuyenDanhBat
    FROM CHUYEN_DANH_BAT
    WHERE MaTauCa = p_MaTauCa AND TrangThaiHoatDong = 'DANG CHO';

    SELECT TrangThaiDuyet
    INTO p_TrangThaiDuyetCDB
    FROM CHUYEN_DANH_BAT
    WHERE MaChuyenDanhBat = p_MaChuyenDanhBat;

    IF p_TrangThaiDuyetCDB = 'CHO DUYET' THEN
        RAISE_APPLICATION_ERROR(-20039, 'Error in update_working_status_depart: CHUYEN DANH BAT CHUA DUOC DUYET');
    ELSIF p_TrangThaiDuyetCDB = 'TU CHOI' THEN
        RAISE_APPLICATION_ERROR(-20040, 'Error in update_working_status_depart: CHUYEN DANH BAT BI TU CHOI');
    END IF;

    UPDATE TAU_CA
    SET TrangThaiHoatDong = 'DANG HOAT DONG'
    WHERE MaTauCa = p_MaTauCa;

    UPDATE CHUYEN_DANH_BAT
    SET TrangThaiHoatDong = 'DANG DANH BAT',
        CangDi = p_CangDi,
        NgayXuatBen = SYSDATE
    WHERE MaTauCa = p_MaTauCa;

EXCEPTION
    WHEN OTHERS THEN
        RAISE_APPLICATION_ERROR(-20041,
            'Error in update_working_status_depart: ' || SQLERRM);
END;
/
--checked

-- Cap nhat trang thai cap cang
CREATE OR REPLACE PROCEDURE update_working_status_dock(
    p_MaTauCa   CHUYEN_DANH_BAT.MaTauCa%TYPE,
    p_CangVe    CHUYEN_DANH_BAT.CangVe%TYPE
)
IS
    p_MaChuyenDanhBat               CHUYEN_DANH_BAT.MaChuyenDanhBat%TYPE;
    p_TrangThaiHoatDongTauCa        TAU_CA.TrangThaiHoatDong%TYPE;
    p_TrangThaiDuyetCDB             CHUYEN_DANH_BAT.TrangThaiDuyet%TYPE;
    p_MaNguTruong                   CHUYEN_DANH_BAT.MaNguTruong%TYPE;
BEGIN
    SELECT TrangThaiHoatDong
    INTO p_TrangThaiHoatDongTauCa
    FROM TAU_CA
    WHERE MaTauCa = p_MaTauCa;

    IF p_TrangThaiHoatDongTauCa = 'DANG HOAT DONG' THEN
        SELECT MaChuyenDanhBat, MaNguTruong
        INTO p_MaChuyenDanhBat, p_MaNguTruong
        FROM CHUYEN_DANH_BAT
        WHERE MaTauCa = p_MaTauCa AND TrangThaiHoatDong = 'DANG DANH BAT';

        UPDATE CHUYEN_DANH_BAT
        SET TrangThaiHoatDong = 'HOAN THANH',
            CangVe = p_CangVe,
            NgayCapBen = SYSDATE
        WHERE MaTauCa = p_MaTauCa;

        UPDATE TAU_CA
        SET TrangThaiHoatDong = 'DANG CHO|CHUA DK'
        WHERE MaTauCa = p_MaTauCa;

        UPDATE NGU_TRUONG
        SET SoLuongTauHienTai = SoLuongTauHienTai - 1
        WHERE MaNguTruong = p_MaNguTruong;
    ELSE 
        RAISE_APPLICATION_ERROR(-20042, 'Error in update_working_status_dock: TAU HIEN TAI KHONG HOAT DONG');
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        RAISE_APPLICATION_ERROR(-20043,
            'Error in update_working_status_dock: ' || SQLERRM);
END;
/
--checked

-- CAP NHAT NHAT KY DANH BAT

-- Insert ME_CA
CREATE OR REPLACE PROCEDURE insert_ME_CA(
    p_MaChuyenDanhBat       CHUYENDANHBAT.MaChuyenDanhBat%TYPE,
    p_ThoiGianThaLuoi       CHUYENDANHBAT.ThoiGianThaLuoi%TYPE,
    p_ThoiGianKeoLuoi       CHUYENDANHBAT.ThoiGianKeoLuoi%TYPE,
    p_ViTriKeoLuoi          VARCHAR2
)
IS
BEGIN
    INSERT INTO ME_CA(MaChuyenDanhBat, ThoiGianThaLuoi, ThoiGianKeoLuoi, ViTriKeoLuoi)
    VALUES (p_MaChuyenDanhBat, p_ThoiGianThaLuoi, p_ThoiGianKeoLuoi, SDO_UTIL.FROM_WKTGEOMETRY(p_ViTriKeoLuoi, 4326));

EXCEPTION
    WHEN OTHERS THEN
        RAISE_APPLICATION_ERROR(-20044,
            'Error in insert_ME_CA: ' || SQLERRM);
END;
/
--checked

--Insert CHI TIET ME_CA
CREATE OR REPLACE PROCEDURE insert_DANHBAT_THUYSAN(
    p_MaChuyenDanhBat       CHUYENDANHBAT.MaChuyenDanhBat%TYPE,
    p_MaMeCa                CHUYENDANHBAT.MaMeCa%TYPE,
    p_MaThuySan             CHUYENDANHBAT.MaThuySan%TYPE,
    p_KhoiLuong             CHUYENDANHBAT.KhoiLuong%TYPE
)
IS
BEGIN
    INSERT INTO DANHBAT_THUYSAN(MaChuyenDanhBat, MaMeCa, MaThuySan, KhoiLuong)
    VALUES (p_MaChuyenDanhBat, p_MaMeCa, p_MaThuySan, p_KhoiLuong);

EXCEPTION
    WHEN OTHERS THEN
        RAISE_APPLICATION_ERROR(-20045,
            'Error in insert_DANHBAT_THUYSAN: ' || SQLERRM);
END;
/
--checked

-- THEO DOI HAI TRINH
-- Lay danh sach LOG toa do
CREATE OR REPLACE PROCEDURE get_log_list_CHUYEN_DANH_BAT(
    p_cursor OUT SYS_REFCURSOR,
    p_MaChuyenDanhBat   CHUYEN_DANH_BAT.MaChuyenDanhBat%TYPE
)
IS
BEGIN
    OPEN p_cursor FOR
        SELECT lht.MaLogHaiTrinh, lht.ThoiGian, lht.ViTri, lht.VanToc, lht.HuongDiChuyen
        FROM LOG_HAI_TRINH lht
        WHERE lht.MaChuyenDanhBat = p_MaChuyenDanhBat;

EXCEPTION
    WHEN OTHERS THEN
        RAISE_APPLICATION_ERROR(-20046,
            'Error in get_log_list_CHUYEN_DANH_BAT: ' || SQLERRM);
END;
/

-- CAP NHAT VI TRI TAU
-- Them 1 diem toa do vao LOG
CREATE OR REPLACE PROCEDURE insert_LOG_HAI_TRINH_for_CHUYEN_DANH_BAT(
    p_MaChuyenDanhBat     LOG_HAI_TRINH.MaChuyenDanhBat%TYPE,
    p_ThoiGian            LOG_HAI_TRINH.ThoiGian%TYPE,
    p_ViTri               VARCHAR2,
    p_VanToc              LOG_HAI_TRINH.VanToc%TYPE,
    p_HuongDiChuyen       LOG_HAI_TRINH.HuongDiChuyen%TYPE
)
IS
   v_exists NUMBER; 
   v_NgayXuatBen CHUYEN_DANH_BAT.NgayXuatBen%TYPE;
BEGIN
    SELECT NgayXuatBen
        INTO v_NgayXuatBen
        FROM CHUYEN_DANH_BAT
    WHERE MaChuyenDanhBat = p_MaChuyenDanhBat;

    SELECT COUNT(*) 
        INTO v_exists
        FROM CHUYEN_DANH_BAT
    WHERE MaChuyenDanhBat = p_MaChuyenDanhBat;

    IF v_exists = 0 THEN
        RAISE_APPLICATION_ERROR(-20047, 
            'insert_LOG_HAI_TRINH_for_CHUYEN_DANH_BAT: Chuyen danh bat khong ton tai.');
    ELSIF p_ThoiGian < v_NgayXuatBen AND p_ThoiGian > SYSDATE THEN
        RAISE_APPLICATION_ERROR(-20047, 
            'insert_LOG_HAI_TRINH_for_CHUYEN_DANH_BAT: ThoiGian khong dung');
    END IF;

    INSERT INTO LOG_HAI_TRINH(MaChuyenDanhBat, ThoiGian, ViTri, VanToc, HuongDiChuyen)
    VALUES (p_MaChuyenDanhBat, p_ThoiGian, SDO_UTIL.FROM_WKTGEOMETRY(p_ViTri, 4326), p_VanToc, p_HuongDiChuyen);

EXCEPTION
    WHEN OTHERS THEN
        RAISE_APPLICATION_ERROR(-20048,
            'Error in insert_LOG_HAI_TRINH_for_CHUYEN_DANH_BAT: ' || SQLERRM);
END;
/
--checked

-- TRUY XUAT NHAT KY DANH BAT
-- Lay nhat ky danh bat
CREATE OR REPLACE PROCEDURE get_fishing_diary(
    thong_tin_tau_cursor OUT SYS_REFCURSOR,
    thong_tin_danh_bat_cursor OUT SYS_REFCURSOR,
    p_MaChuyenDanhBat          CHUYEN_DANH_BAT.MaChuyenDanhBatTauCa%TYPE 
)
IS
BEGIN
    OPEN thong_tin_tau_cursor FOR 
        SELECT 
            ct.HoTen,
            tc.MaTauCa, tc.SoDangKy, tc.LoaiTau, tc.ChieuDai, tc.CongSuat,
            nghe_chinh.TenNghe,
            cdb.MaChuyenDanhBat, cdb.NgayXuatBen, cdb.NgayCapBen, cdb.CangDi, cdb.CangVe,
            nghe_chinh.TenNghe
        FROM CHUYEN_DANH_BAT cdb
        JOIN CHU_TAU ct ON ct.MaChuTau = cdb.MaChuTau
        JOIN TAU_CA tc ON tc.MaTauCa = cdb.MaTauCa
        JOIN NGHE nghe_chinh ON nghe_chinh.MaNghe = tc.MaNgheChinh
        JOIN TAU_NGHE tau_nghe ON tau_nghe.MaTauCa = tc.MaTauCa
        WHERE cdb.MaChuyenDanhBat = p_MaChuyenDanhBat;

    OPEN thong_tin_danh_bat_cursor FOR 
        SELECT 
            mc.MaMeCa, 
            mc.KhoiLuongMeCa, 
            mc.ThoiGianThaLuoi, 
            mc.ThoiGianKeoLuoi, 
            DBMS_LOB.SUBSTR(SDO_UTIL.TO_WKTGEOMETRY(mc.ViTriKeoLuoi), 4000, 1) AS ViTriWKT,
            LISTAGG(ts.TenLoaiThuySan || ': ' || dbts.KhoiLuong || 'kg', ', ') 
                WITHIN GROUP (ORDER BY ts.TenLoaiThuySan ASC) AS ChiTietMeCa
        FROM ME_CA mc
        JOIN DANHBAT_THUYSAN dbts ON dbts.MaMeCa = mc.MaMeCa AND dbts.MaChuyenDanhBat = mc.MaChuyenDanhBat
        JOIN THUY_SAN ts ON ts.MaThuySan = dbts.MaThuySan
        WHERE mc.MaChuyenDanhBat = p_MaChuyenDanhBat
        GROUP BY             
            mc.MaMeCa, 
            mc.KhoiLuongMeCa, 
            mc.ThoiGianThaLuoi, 
            mc.ThoiGianKeoLuoi, 
            DBMS_LOB.SUBSTR(SDO_UTIL.TO_WKTGEOMETRY(mc.ViTriKeoLuoi), 4000, 1);

EXCEPTION
    WHEN OTHERS THEN
        RAISE_APPLICATION_ERROR(-20049,
            'Error in get_fishing_diary: ' || SQLERRM);
END;
/
--checked

-- Insert VI_PHAM
-- tuong tu voi insert_NGU_TRUONG
CREATE OR REPLACE PROCEDURE insert_VI_PHAM(
    p_MaChuyenDanhBat   VI_PHAM.MaChuyenDanhBat%TYPE,
    p_ViTri             VARCHAR2,
    p_MoTa              VI_PHAM.MoTa%TYPE
)
IS
BEGIN
    INSERT INTO VI_PHAM(MaChuyenDanhBat, ViTri, MoTa)
    VALUES (p_MaChuyenDanhBat, SDO_UTIL.FROM_WKTGEOMETRY(p_ViTri, 4326), p_MoTa);

EXCEPTION
    WHEN OTHERS THEN
        RAISE_APPLICATION_ERROR(-20050,
            'Error in insert_VI_PHAM: ' || SQLERRM);
END;
/

--DE XUAT CHINH SUA
CREATE OR REPLACE PROCEDURE insert_VI_PHAM(
    p_MaChuyenDanhBat   IN VI_PHAM.MaChuyenDanhBat%TYPE,
    p_ViTri_WKT         IN VARCHAR2,
    p_MoTa              IN VI_PHAM.MoTa%TYPE
)
IS
    v_ViTri SDO_GEOMETRY;
BEGIN
    -- 1) Chuyển WKT sang SDO_GEOMETRY và gán SRID
    BEGIN
        v_ViTri := SDO_UTIL.FROM_WKTGEOMETRY(p_ViTri_WKT);
        v_ViTri.SDO_SRID := 4326;
    EXCEPTION
        WHEN OTHERS THEN
            RAISE_APPLICATION_ERROR(
                -20050,
                'Error in insert_VI_PHAM: WKT không hợp lệ. ' || SQLERRM);
    END;

    -- 2) Thêm dữ liệu vào bảng VI_PHAM
    INSERT INTO VI_PHAM (
        MaChuyenDanhBat,
        ViTri,
        MoTa
    ) VALUES (
        p_MaChuyenDanhBat,
        v_ViTri,
        p_MoTa
    );

EXCEPTION
    WHEN OTHERS THEN
        RAISE_APPLICATION_ERROR(
            -20066,
            'Error in insert_VI_PHAM: ' || SQLERRM
        );
END insert_VI_PHAM;
/
--checked

-- Cap nhat MoTa cua VI_PHAM
CREATE OR REPLACE PROCEDURE update_description_VI_PHAM(
    p_MaViPham          VI_PHAM.MaViPham%TYPE,
    p_MoTa              VI_PHAM.MoTa%TYPE
)
IS
BEGIN
    UPDATE VI_PHAM
    SET MoTa = p_MoTa
    WHERE MaViPham = p_MaViPham;

EXCEPTION
    WHEN OTHERS THEN
        RAISE_APPLICATION_ERROR(-20051,
            'Error in update_description_VI_PHAM: ' || SQLERRM);
END;
/
--checked

--3.NGU TRUONG

-- THEM THONG TIN NGU TRUONG
-- insert_NGU_TRUONG
-- LOI
CREATE OR REPLACE PROCEDURE insert_NGU_TRUONG(
    p_TenNguTruong        NGU_TRUONG.TenNguTruong%TYPE,
    p_ViTri               CLOB,
    p_SoLuongTauToiDa     NGU_TRUONG.SoLuongTauToiDa%TYPE
)
IS 
    v_ViTri SDO_GEOMETRY;
BEGIN
    BEGIN
        -- ham FROM_WKTGEOMETRY chi nhan 1 tham so , SRID ban dau = NULL --> phai set sau 
        v_ViTri := SDO_UTIL.FROM_WKTGEOMETRY(DBMS_LOB.SUBSTR(p_ViTri, 32767, 1), 4326);
    EXCEPTION
        WHEN OTHERS THEN
            RAISE_APPLICATION_ERROR(-20052, 'Error in insert_NGU_TRUONG: WKT không hợp lệ, ' || SQLERRM);
    END;

    INSERT INTO NGU_TRUONG (TenNguTruong, ViTri, SoLuongTauToiDa)
        VALUES (p_TenNguTruong, v_ViTri, p_SoLuongTauToiDa);

EXCEPTION
    WHEN OTHERS THEN
        RAISE_APPLICATION_ERROR(-20053,
            'Error in insert_NGU_TRUONG: ' || SQLERRM);
END;
/

-- DE XUAT CHINH SUA
CREATE OR REPLACE PROCEDURE insert_NGU_TRUONG(
    p_TenNguTruong      IN NGU_TRUONG.TenNguTruong%TYPE,
    p_ViTri_WKT         IN CLOB,
    p_SoLuongTauToiDa   IN NGU_TRUONG.SoLuongTauToiDa%TYPE
)
IS
    v_WktShort  VARCHAR2(32767);
    v_ViTri     SDO_GEOMETRY;
BEGIN
    -- 1. Lấy chuỗi WKT (tối đa 32767 ký tự) từ CLOB
    v_WktShort := DBMS_LOB.SUBSTR(p_ViTri_WKT, 32767, 1);

    -- 2. Chuyển WKT thành SDO_GEOMETRY (SRID ban đầu = NULL)
    BEGIN
        v_ViTri := SDO_UTIL.FROM_WKTGEOMETRY(v_WktShort);
    EXCEPTION
        WHEN OTHERS THEN
            RAISE_APPLICATION_ERROR(
                -20052,
                'Error in insert_NGU_TRUONG: WKT không hợp lệ. ' || SQLERRM
            );
    END;

    -- 3. Gán SRID = 4326 cho đối tượng geometry vừa tạo
    v_ViTri.SDO_SRID := 4326;

    -- 4. Thực hiện chèn vào bảng (MaNguTruong do trigger tự sinh)
    INSERT INTO NGU_TRUONG (
      TenNguTruong,
      ViTri,
      SoLuongTauToiDa
    )
    VALUES (
      p_TenNguTruong,
      v_ViTri,
      p_SoLuongTauToiDa
    );

EXCEPTION
    WHEN OTHERS THEN
        RAISE_APPLICATION_ERROR(
            -20053,
            'Error in insert_NGU_TRUONG: ' || SQLERRM
        );
END insert_NGU_TRUONG;
/

--checked

-- XEM THONG TIN NGU TRUONG
-- Lay thong tin NGU_TRUONG
CREATE OR REPLACE PROCEDURE get_fishery_info(
    ngu_truong_cursor OUT SYS_REFCURSOR,
    p_MaNguTruong       NGU_TRUONG.MaNguTruong%TYPE
)
IS
BEGIN

    OPEN ngu_truong_cursor FOR
        SELECT ng.TenNguTruong, DBMS_LOB.SUBSTR(SDO_UTIL.TO_WKTGEOMETRY(ng.ViTri), 32767, 1) AS ViTriWKT, ng.SoLuongTauToiDa, ng.SoLuongTauHienTai
        FROM NGU_TRUONG ng 
        WHERE ng.MaNguTruong = p_MaNguTruong;

EXCEPTION
    WHEN OTHERS THEN
    RAISE_APPLICATION_ERROR(-20054,
            'Error in get_fishery_info: ' || SQLERRM);
END;
/
--checked

--4. THONG KE
-- VI_PHAM
-- Lay danh sach VI_PHAM
CREATE OR REPLACE PROCEDURE get_list_VI_PHAM(
    vi_pham_cursor OUT SYS_REFCURSOR
)
IS
BEGIN
    OPEN vi_pham_cursor FOR
        SELECT vp.MaViPham, vp.MaChuyenDanhBat, cdb.MaTauCa, vp.ThoiGian, DBMS_LOB.SUBSTR(SDO_UTIL.TO_WKTGEOMETRY(vp.ViTri), 32767, 1) AS ViTriWKT, vp.MoTa
        FROM VI_PHAM vp
        JOIN CHUYEN_DANH_BAT cdb ON cdb.MaChuyenDanhBat = vp.MaChuyenDanhBat; 

EXCEPTION
    WHEN OTHERS THEN
    RAISE_APPLICATION_ERROR(-20055,
            'Error in get_list_VI_PHAM: ' || SQLERRM);
END;
/
--checked

-- THONG KE SO LUONG VI PHAM THEO TAU
CREATE OR REPLACE PROCEDURE statistics_VI_PHAM_by_TAU_CA(
    vi_pham_cursor OUT SYS_REFCURSOR
)
IS
BEGIN
    OPEN vi_pham_cursor FOR
        SELECT tc.MaTauCa, tc.SoDangKy, count(vp.MaViPham) AS SoLuongLoiViPham
        FROM TAU_CA tc
        JOIN CHUYEN_DANH_BAT cdb ON cdb.MaTauCa = tc.MaTauCa
        LEFT JOIN VI_PHAM vp ON vp.MaChuyenDanhBat = cdb.MaChuyenDanhBat
        GROUP BY tc.MaTauCa, tc.SoDangKy
        ORDER BY SoLuongLoiViPham DESC;

EXCEPTION
    WHEN OTHERS THEN
    RAISE_APPLICATION_ERROR(-20056,
            'Error in statistics_VI_PHAM_by_TAU_CA: ' || SQLERRM);
END;
/
--checked

-- THUY SAN
-- THONG KE SAN LUONG THEO LOAI THUY SAN
CREATE OR REPLACE PROCEDURE statistics_seafood_output_by_species(
    thuy_san_cursor OUT SYS_REFCURSOR
)
IS
BEGIN
    OPEN thuy_san_cursor FOR
        SELECT ts.MaThuySan, ts.TenLoaiThuySan, SUM(dbts.KhoiLuong) AS TongKhoiLuong
        FROM THUY_SAN ts
        JOIN DANHBAT_THUYSAN dbts ON dbts.MaThuySan = ts.MaThuySan
        GROUP BY ts.MaThuySan, ts.TenLoaiThuySan;

EXCEPTION
    WHEN OTHERS THEN
    RAISE_APPLICATION_ERROR(-20057,
            'Error in statistics_seafood_output_by_species: ' || SQLERRM);
END;
/
--checked

-- BAO
-- THONG KE SO LUONG BAO THEO NAM
CREATE OR REPLACE PROCEDURE statistics_storm_count_by_year(
    bao_cursor OUT SYS_REFCURSOR
)
IS
BEGIN
    OPEN bao_cursor FOR
        SELECT EXTRACT(YEAR FROM lddb.ThoiGian) AS Nam,
                COUNT(DISTINCT b.MaBao) AS SoLuongBao
        FROM BAO b
        JOIN LOG_DUONG_DI_BAO lddb ON lddb.MaBao = b.MaBao
        GROUP BY EXTRACT(YEAR FROM lddb.ThoiGian)
        ORDER BY Nam;

EXCEPTION
    WHEN OTHERS THEN
    RAISE_APPLICATION_ERROR(-20058,
            'Error in statistics_storm_count_by_year: ' || SQLERRM);
END;
/
--checked

--5. KHI TUONG THUY VAN
-- insert THOI_TIET
CREATE OR REPLACE PROCEDURE insert_THOI_TIET(
    p_ThoiGianDuBao     THOI_TIET.ThoiGianDuBao%TYPE,
    p_KhuVucAnhHuong    THOI_TIET.KhuVucAnhHuong%TYPE,
    p_ChiTietDuBao      THOI_TIET.ChiTietDuBao%TYPE
)
IS
BEGIN
    INSERT INTO THOI_TIET(ThoiGianDuBao, KhuVucAnhHuong, ChiTietDuBao)
    VALUES (p_ThoiGianDuBao, p_KhuVucAnhHuong, p_ChiTietDuBao);

EXCEPTION
    WHEN OTHERS THEN
    RAISE_APPLICATION_ERROR(-20059,
            'Error in insert_THOI_TIET: ' || SQLERRM);
END;
/
--checked

-- insert BAO
CREATE OR REPLACE PROCEDURE insert_BAO(
    p_TenBao    BAO.TenBao%TYPE
)
IS
BEGIN
    INSERT INTO BAO(TENBAO)
    VALUES (p_TenBao);

EXCEPTION
    WHEN OTHERS THEN
    RAISE_APPLICATION_ERROR(-20060,
            'Error in insert_BAO: ' || SQLERRM);
END;
/
--checked

-- insert LOG_DUONG_DI_BAO
CREATE OR REPLACE PROCEDURE insert_LOG_DUONG_DI_BAO(
    p_MaBao           LOG_DUONG_DI_BAO.MaBao%TYPE,
    p_ThoiGian        LOG_DUONG_DI_BAO.ThoiGian%TYPE,
    p_ViTriWKT        VARCHAR2,
    p_MucDo           LOG_DUONG_DI_BAO.MucDo%TYPE
)
IS
    v_ViTri SDO_GEOMETRY;
BEGIN
    BEGIN
        v_ViTri := SDO_UTIL.FROM_WKTGEOMETRY(p_ViTriWKT, 4326);

        EXCEPTION
            WHEN OTHERS THEN
                RAISE_APPLICATION_ERROR(-20061, 'Error in insert_LOG_DUONG_DI_BAO:  WKT không hợp lệ, '||SQLERRM);
    END;
    
    INSERT INTO LOG_DUONG_DI_BAO(MaBao, ThoiGian, ViTri, MucDo)
        VALUES (p_MaBao, p_ThoiGian, v_ViTri, p_MucDo);

EXCEPTION
    WHEN OTHERS THEN
    RAISE_APPLICATION_ERROR(-20062,
            'Error in insert_LOG_DUONG_DI_BAO: ' || SQLERRM);
END;
/
--checked

-- VI. CREATE FUNCTION
--  Kiem tra dang nhap
CREATE OR REPLACE FUNCTION Fn_dang_nhap(
    p_username      APP_USER.USERNAME%TYPE,
    p_password      APP_USER.PASSWORD%TYPE
) RETURN NVARCHAR2
IS
    f_user_id NVARCHAR2(20);
BEGIN
    SELECT USER_ID
    INTO f_user_id
    FROM APP_USER
    WHERE USERNAME = p_username AND PASSWORD = p_password;

    RETURN USER_ID;

EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RETURN NULL;

    WHEN OTHERS THEN    
        RAISE_APPLICATION_ERROR(-20063,
                'Error in Fn_dang_nhap: ' || SQLERRM);
END;
/
--checked

-- Kiem tra so luong tau hien tai
CREATE OR REPLACE FUNCTION Fn_kiem_tra_so_luong_tau (
    p_MaNguTruong      NGU_TRUONG.MaNguTruong%TYPE
) RETURN BOOLEAN
IS
    f_HienTai       NGU_TRUONG.SoLuongTauHienTai%TYPE;
    f_ToiDa         NGU_TRUONG.SoLuongTauToiDa%TYPE;
BEGIN
    SELECT SoLuongTauHienTai, SoLuongTauToiDa
    INTO f_HienTai, f_ToiDa
    FROM NGU_TRUONG
    WHERE MaNguTruong = p_MaNguTruong;

    RETURN f_HienTai < f_ToiDa;
EXCEPTION
    WHEN OTHERS THEN    
        RAISE_APPLICATION_ERROR(-20064,
                'Error in Fn_kiem_tra_so_luong_tau: ' || SQLERRM);
END;
/
--checked

-- VII. TEST CASE

--Lay danh sach tau cua chu tau
VAR c REFCURSOR;
EXEC Hien_thi_danh_sach_tau_ca_cua_chu_tau(:c, 'USER01');
PRINT c;


INSERT INTO APP_USER (USERNAME, PASSWORD, ROLE)
VALUES ('admin1', 'passAdmin', 'ADMIN');

INSERT INTO APP_USER (USERNAME, PASSWORD, ROLE)
VALUES ('chutau1', 'passChuTau', 'CHUTAU');

SELECT * 
FROM APP_USER;

INSERT INTO ADMIN (MaAdmin, HoTen, CoQuan, CCCD)
VALUES ('USER1', 'Nguyễn Văn A', 'Bộ Tài nguyên Môi trường', '123456789');

INSERT INTO CHU_TAU (MaChuTau, HoTen, SDT, DiaChi, CCCD, TrangThaiDuyet)
VALUES ('USER2', 'Trần Thị B', '0987654321', 'Hải Phòng', '987654321', 'DA DUYET');

select *
from CHU_TAU;

select *
from ADMIN;

INSERT INTO NGHE (TenNghe) VALUES ('Cá biển');
INSERT INTO NGHE (TenNghe) VALUES ('Cá sông');

select *
from NGHE;

INSERT INTO TAU_CA (
  SoDangKy, LoaiTau, ChieuDai, CongSuat, NamDongTau,
  TrangThaiDuyet, TrangThaiHoatDong, MaChuTau, MaNgheChinh
) VALUES (
  'DK001', 'Tàu đánh cá xa bờ', 30.5, 120.0, 2018,
  'DA DUYET', 'DANG HOAT DONG', 'USER2', 'NGHE1'
);

select * 
from TAU_CA;

INSERT INTO TAU_NGHE (MaTauCa, MaNghe, VungHoatDong)
VALUES ('TC1', 'NGHE2', 'Vịnh Hạ Long');

select *
from TAU_NGHE;


INSERT INTO NGU_TRUONG (
  TenNguTruong,
  ViTri,
  SoLuongTauHienTai,
  SoLuongTauToiDa
) VALUES (
  'Ngư trường A',
  -- Khởi tạo SDO_GEOMETRY với SRID = 4326
  SDO_GEOMETRY(
    2003,             -- SDO_GTYPE: 2003 nghĩa là POLYGON
    4326,             -- SDO_SRID
    NULL,             -- SDO_POINT (NULL vì đây là POLYGON, không dùng point)
    SDO_ELEM_INFO_ARRAY(1,1003,1),
    SDO_ORDINATE_ARRAY(
      0, 0,
      0, 10,
      10, 10,
      10, 0,
      0, 0
    )
  ),
  0,      -- SoLuongTauHienTai mặc định = 0
  1000    -- SoLuongTauToiDa
);
COMMIT;


select *
from NGU_TRUONG;


select *
from NGU_TRUONG;

SELECT 
  MaNguTruong,
  TenNguTruong,
  SDO_UTIL.TO_WKTGEOMETRY(ViTri) AS ViTri_WKT,
  SoLuongTauHienTai,
  SoLuongTauToiDa
FROM NGU_TRUONG;

SELECT MaNguTruong,
  TenNguTruong,
  SUBSTR(
    SDO_UTIL.TO_WKTGEOMETRY(ViTri), 
    INSTR(SDO_UTIL.TO_WKTGEOMETRY(ViTri),'((') + 1,
    INSTR(SDO_UTIL.TO_WKTGEOMETRY(ViTri),'))') 
    - INSTR(SDO_UTIL.TO_WKTGEOMETRY(ViTri),'((') - 1
  ) AS ToaDoOnly
FROM NGU_TRUONG;



INSERT INTO CHUYEN_DANH_BAT (
  NgayXuatBen, NgayCapBen, CangDi, CangVe,
  TongKhoiLuong, TrangThaiDuyet, TrangThaiHoatDong, MaTauCa, MaNguTruong
) VALUES (
  TO_DATE('2025-06-01','YYYY-MM-DD'),
  TO_DATE('2025-06-05','YYYY-MM-DD'),
  'Cảng Hải Phòng',
  'Cảng Đà Nẵng',
  0,
  'DANG CHO',
  'DANG CHO',
  'TC1',
  'NT1'
);

select *
from CHUYEN_DANH_BAT;

--test procedure insert_NGU_TRUONG
BEGIN
  -- Thêm ngư trường với WKT hợp lệ
  insert_NGU_TRUONG(
    'Ngư trường Test 1',
    'POLYGON((2 2, 2 4, 4 4, 4 2, 2 2))',  -- WKT mô tả hình vuông
    5                                      -- Số lượng tàu tối đa
  );
  COMMIT;
END;
/

INSERT INTO LOG_HAI_TRINH (
  MaChuyenDanhBat, ThoiGian, ViTri, VanToc, HuongDiChuyen
) VALUES (
  'CDP2',
  SYSTIMESTAMP,
  SDO_GEOMETRY(
    2001, 
    4326,
    SDO_POINT_TYPE(5,5,NULL),
    NULL, NULL
  ),
  8.5,
  'Đông Nam'
);


select *
from LOG_HAI_TRINH;

SELECT * FROM VI_PHAM;


INSERT INTO THUY_SAN (TenLoaiThuySan) VALUES ('Ca thu');

SELECT * FROM THUY_SAN;







from PySide2.QtCore import *
from PySide2.QtGui import *
from PySide2.QtWidgets import *
from PIL import Image, ImageDraw, ImageFont
from barcode.writer import ImageWriter
import barcode
import os

# 99% of these definitions are made by the Qt Designer for the actual
# layout of the GUI.
class Ui_badgeWindow(QMainWindow):
    def setupUi(self, badgeWindow):
        if not badgeWindow.objectName():
            badgeWindow.setObjectName(u"badgeWindow")
        badgeWindow.resize(512, 240)
        badgeWindow.setMinimumSize(QSize(512, 240))
        badgeWindow.setMaximumSize(QSize(512, 240))
        self.line = QFrame(badgeWindow)
        self.line.setObjectName(u"line")
        self.line.setGeometry(QRect(110, 10, 20, 211))
        self.line.setFrameShape(QFrame.VLine)
        self.line.setFrameShadow(QFrame.Sunken)
        self.empNameField = QLineEdit(badgeWindow)
        self.empNameField.setObjectName(u"empNameField")
        self.empNameField.setGeometry(QRect(150, 30, 211, 20))
        self.empSiteField = QLineEdit(badgeWindow)
        self.empSiteField.setObjectName(u"empSiteField")
        self.empSiteField.setGeometry(QRect(150, 80, 211, 20))
        self.nameLbl = QLabel(badgeWindow)
        self.nameLbl.setObjectName(u"nameLbl")
        self.nameLbl.setGeometry(QRect(150, 10, 141, 16))
        self.siteLbl = QLabel(badgeWindow)
        self.siteLbl.setObjectName(u"siteLbl")
        self.siteLbl.setGeometry(QRect(150, 60, 161, 16))
        self.jobLbl = QLabel(badgeWindow)
        self.jobLbl.setObjectName(u"jobLbl")
        self.jobLbl.setGeometry(QRect(150, 110, 111, 16))
        self.empJobField = QLineEdit(badgeWindow)
        self.empJobField.setObjectName(u"empJobField")
        self.empJobField.setGeometry(QRect(150, 130, 211, 20))
        self.browseBtn = QPushButton(badgeWindow)
        self.browseBtn.setObjectName(u"browseBtn")
        self.browseBtn.setGeometry(QRect(20, 160, 81, 41))
        font = QFont()
        font.setBold(True)
        font.setWeight(75)
        self.browseBtn.setFont(font)
        self.imgPreview = QGraphicsView(badgeWindow)
        self.imgPreview.setObjectName(u"imgPreview")
        self.imgPreview.setGeometry(QRect(20, 40, 80, 100))
        self.imgPreview.setMinimumSize(QSize(80, 100))
        self.imgPreview.setMaximumSize(QSize(80, 100))
        self.staffToggle = QRadioButton(badgeWindow)
        self.staffToggle.setObjectName(u"staffToggle")
        self.staffToggle.setGeometry(QRect(150, 210, 82, 17))
        self.staffToggle.setFont(font)
        self.teacherToggle = QRadioButton(badgeWindow)
        self.teacherToggle.setObjectName(u"teacherToggle")
        self.teacherToggle.setGeometry(QRect(290, 210, 82, 17))
        self.teacherToggle.setFont(font)
        self.previewLbl = QLabel(badgeWindow)
        self.previewLbl.setObjectName(u"previewLbl")
        self.previewLbl.setGeometry(QRect(20, 20, 81, 16))
        self.previewLbl.setLayoutDirection(Qt.LeftToRight)
        self.previewLbl.setAlignment(Qt.AlignCenter)
        self.empIDfield = QLineEdit(badgeWindow)
        self.empIDfield.setObjectName(u"empIDfield")
        self.empIDfield.setGeometry(QRect(150, 180, 211, 20))
        self.idLbl = QLabel(badgeWindow)
        self.idLbl.setObjectName(u"idLbl")
        self.idLbl.setGeometry(QRect(150, 160, 111, 16))
        self.generateBtn = QPushButton(badgeWindow)
        self.generateBtn.setObjectName(u"generateBtn")
        self.generateBtn.setGeometry(QRect(380, 80, 121, 71))
        font1 = QFont()
        font1.setPointSize(11)
        font1.setBold(True)
        font1.setItalic(False)
        font1.setWeight(75)
        self.generateBtn.setFont(font1)

        self.retranslateUi(badgeWindow)

        # Some variables we'll need.
        self.image_path = ""

        self.generateBtn.clicked.connect(self.generateBadge)
        self.browseBtn.clicked.connect(self.browseForImage)
        QMetaObject.connectSlotsByName(badgeWindow)
    # setupUi

    def retranslateUi(self, badgeWindow):
        badgeWindow.setWindowTitle(QCoreApplication.translate("badgeWindow", u"CPS Badge Generator", None))
        self.nameLbl.setText(QCoreApplication.translate("badgeWindow", u"Employee Name (Last, First)", None))
        self.siteLbl.setText(QCoreApplication.translate("badgeWindow", u"Employee Site Code (2-chars)", None))
        self.jobLbl.setText(QCoreApplication.translate("badgeWindow", u"Employee Job Title", None))
        self.browseBtn.setText(QCoreApplication.translate("badgeWindow", u"Browse for\n" "Photo", None))
        self.staffToggle.setText(QCoreApplication.translate("badgeWindow", u"Staff?", None))
        self.teacherToggle.setText(QCoreApplication.translate("badgeWindow", u"Teacher?", None))
        self.previewLbl.setText(QCoreApplication.translate("badgeWindow", u"80x100 Preview", None))
        self.idLbl.setText(QCoreApplication.translate("badgeWindow", u"Employee MAS ID", None))
        self.generateBtn.setText(QCoreApplication.translate("badgeWindow", u"GENERATE\n" "BADGE", None))
    # retranslateUi

    # ACTUAL FUNCTIONS
    def browseForImage(self):
        file_dialog = QFileDialog()
        image_path, _ = file_dialog.getOpenFileName(None, "Select Image", "", "Image Files (*.png *.jpg *.jpeg)")
        print("Image Path:", image_path)
        self.image_path = image_path

        # Create a thumbnail of the selected image
        image = Image.open(image_path)
        image.thumbnail((80, 100))

        # Convert the PIL image to QPixmap
        q_image = QImage(image_path)
        pixmap = QPixmap.fromImage(q_image)

        # Scale the pixmap to fit the desired size
        scaled_pixmap = pixmap.scaled(80, 100, Qt.KeepAspectRatio, Qt.SmoothTransformation)

        # Create a QGraphicsScene and QGraphicsPixmapItem
        scene = QGraphicsScene()
        pixmap_item = scene.addPixmap(scaled_pixmap)

        # Set the scene on the QGraphicsView
        self.imgPreview.setScene(scene)
        self.imgPreview.fitInView(pixmap_item, Qt.AspectRatioMode.KeepAspectRatio)

    
    def generateBadge(self):
        employeeName = self.empNameField.text()
        employeeSite = self.empSiteField.text()
        employeeJobTitle = self.empJobField.text()
        employeeID = self.empIDfield.text()

        if not all((employeeName, employeeSite, employeeJobTitle, employeeID, self.image_path)):
            # TODO: Popup window
            print("fill in the fields")

        else:
            print(f"{employeeName} {employeeSite} {employeeJobTitle} {employeeID} {self.image_path}")
            card_width = 3.37 * 300  # CR-80 card width in inches (converted to pixels at 300 DPI)
            card_height = 2.125 * 300  # CR-80 card height in inches (converted to pixels at 300 DPI)
            card_image = Image.new("RGB", (int(card_width), int(card_height)), "white")
            draw = ImageDraw.Draw(card_image)

            # Set the font properties for the text
            font_path = "C:\\Windows\\Fonts\\Arial.ttf"  # Specify the path to your font file
            font_size = 20
            font = ImageFont.truetype(font_path, font_size)

            # Draw the employee name
            draw.text((10, 10), employeeName, fill="black", font=font)

            # Draw the employee site
            draw.text((10, 40), employeeSite, fill="black", font=font)

            # Draw the employee job title
            draw.text((10, 70), employeeJobTitle, fill="black", font=font)

            # Draw the employee ID barcode at the bottom
            barcode_image = barcode.get("code128", employeeID, writer=ImageWriter())
            barcode_filename = "barcode.png"
            barcode_path = os.path.join(os.getcwd(), barcode_filename)
            barcode_image.save(barcode_path)
            barcode_image = Image.open(barcode_path)
            card_image.paste(barcode_image, (10, int(card_height) - barcode_image.size[1] - 10))

            # Save the populated card image as testimg.jpg in the current working directory
            save_path = os.path.join(os.getcwd(), "testimg.jpg")
            card_image.save(save_path, "JPEG", quality=100)

            print("CR-80 sized card generated as testimg.jpg.")

            # If you want to copy the image instead of saving, use the following line instead
            # shutil.copyfile(self.image_path, save_path)

if __name__ == "__main__":
    import sys

    app = QApplication(sys.argv)
    badgeWindow = QMainWindow()
    ui = Ui_badgeWindow()
    ui.setupUi(badgeWindow)
    badgeWindow.show()
    sys.exit(app.exec_())

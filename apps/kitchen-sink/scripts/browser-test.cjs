const { chromium } = require('playwright');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const root = path.resolve(__dirname, '..');
const base = process.env.KITCHEN_SINK_URL || 'http://127.0.0.1:8090';
const results = [];
const errors = [];
const markupFindings = [];
const unexpectedConsoleErrors = [];
const screenshots = path.join(root,'test-results');
fs.mkdirSync(screenshots,{recursive:true});
(async()=>{
  const browser = await chromium.launch({headless:true,channel:process.env.PLAYWRIGHT_CHANNEL || 'chrome'});
  const page = await browser.newPage({viewport:{width:1440,height:1000}});
  page.setDefaultTimeout(8000);
  page.on('pageerror',error=>errors.push(error.message));
  page.on('console',message=>{if(message.type()==='error' && !/Failed to load resource: the server responded with a status of (422|503)/.test(message.text())) unexpectedConsoleErrors.push(message.text());});
  async function test(name, run) {
    try { await run(); results.push({name,passed:true}); console.log('PASS '+name); }
    catch(error) { results.push({name,passed:false,error:error.message}); console.error('FAIL '+name+': '+error.message); await page.screenshot({path:path.join(screenshots,'failure-'+results.length+'.png'),fullPage:false}); }
  }
  let navigation = 0;
  async function go(group) {
    await page.goto(base+'/?test='+ (++navigation) +'#/'+group);
    await page.getByRole('heading',{name:group,exact:true}).first().waitFor();
    await page.getByText('Connecting to Go / SQLite…',{exact:true}).waitFor({state:'hidden'});
  }
  const groups = ['Foundations','Actions','Feedback','Inputs','Choosing','Dates','Data','Content','Overlays','Structure','Dashboard','Icons','Collaboration','Access','AI','Files','Rules','Forms','Processes'];
  for(const group of groups) await test('render '+group,async()=>{
    await go(group);
    assert.equal(await page.locator('main').count(),1);
    await page.screenshot({path:path.join(screenshots,group.toLowerCase()+'.png'),fullPage:false});
    assert.equal(errors.length,0,errors.join('\n'));
    const findings = await page.evaluate(()=>{
      const result=[];
      const ids=[...document.querySelectorAll('[id]')].map(e=>e.id);
      for(const id of new Set(ids.filter((id,i)=>ids.indexOf(id)!==i))) result.push({kind:'duplicate-id',id});
      for(const el of document.querySelectorAll('[aria-controls],[aria-labelledby],[aria-describedby],[aria-activedescendant]')) {
        for(const attr of ['aria-controls','aria-labelledby','aria-describedby','aria-activedescendant']) for(const id of (el.getAttribute(attr)||'').split(/\s+/).filter(Boolean)) if(!document.getElementById(id)) result.push({kind:'missing-aria-target',element:el.id||el.tagName,attr,id});
      }
      for(const el of document.querySelectorAll('label[for]')) if(!document.getElementById(el.htmlFor)) result.push({kind:'missing-label-target',id:el.htmlFor});
      return result;
    });
    markupFindings.push(...findings.map(f=>({group,...f})));
    assert.equal(findings.length,0,JSON.stringify(findings));
  });
  await test('text entry and SQLite snapshot survive reload',async()=>{
    await go('Inputs');
    await page.getByLabel('Customer name',{exact:true}).fill('Browser saved customer');
    await page.getByRole('button',{name:'Save snapshot',exact:true}).first().click();
    await page.getByText('Saved to SQLite',{exact:true}).first().waitFor();
    await page.reload();
    await page.getByLabel('Customer name',{exact:true}).waitFor();
    await page.waitForFunction(()=>document.querySelector('#text')?.value==='Browser saved customer');
  });
  await test('select keyboard selection and return focus',async()=>{
    await go('Choosing');
    const trigger = page.locator('#select');
    await trigger.focus(); await page.keyboard.press('Enter');
    await page.locator('#component-Select').getByRole('option',{name:'Oslo',exact:true}).waitFor();
    await page.keyboard.press('ArrowDown'); await page.keyboard.press('Enter');
    assert.equal(await page.evaluate(()=>document.activeElement.id),'select');
    assert.equal(await trigger.getAttribute('aria-expanded'),'false');
  });
  await test('modal Escape restores opener focus',async()=>{
    await go('Overlays');
    await page.getByRole('button',{name:'Open modal',exact:true}).click();
    await page.getByRole('dialog',{name:'Edit customer'}).waitFor();
    await page.keyboard.press('Escape');
    await page.getByRole('dialog',{name:'Edit customer'}).waitFor({state:'hidden'});
    await page.waitForFunction(()=>document.activeElement.id==='open-modal');
  });
  await test('command palette shortcut',async()=>{
    await go('Overlays');
    await page.keyboard.press('Control+k');
    await page.getByRole('dialog').waitFor();
    await page.keyboard.press('Escape');
    await page.getByRole('dialog').waitFor({state:'hidden'});
  });
  await test('remote refresh retains data on failure and can recover',async()=>{
    await go('Dashboard');
    await page.getByText('250 orders received from Go / SQLite.',{exact:true}).waitFor();
    await page.getByRole('button',{name:'Failure / old data',exact:true}).click();
    await page.getByText('Request failed; previous data is retained',{exact:true}).waitFor();
    assert(await page.getByText('250 orders received from Go / SQLite.',{exact:true}).isVisible());
    await page.getByRole('button',{name:'Data',exact:true}).click();
    await page.getByText('Loaded from Go / SQLite',{exact:true}).waitFor();
  });
  await test('server list search makes a filtered Go request',async()=>{
    await go('Rules');
    const card=page.locator('#component-ServerList');
    const search=card.getByRole('textbox').first();
    await search.fill('Aurora');
    await page.waitForResponse(r=>r.url().endsWith('/api/orders/query') && r.request().postDataJSON()?.search==='Aurora');
    await page.waitForTimeout(150);
    assert((await card.innerText()).includes('Aurora'));
    assert(!(await card.innerText()).includes('Fjord Foods'));
  });
  await test('form validation then server field rejection',async()=>{
    await go('Forms');
    await page.locator('#customer-form-name').fill('');
    await page.getByRole('button',{name:'Save customer',exact:true}).click();
    await page.getByText('Required',{exact:true}).first().waitFor();
    await page.locator('#customer-form-name').fill('Browser customer');
    await page.locator('#customer-form-email').fill('taken@example.com');
    await page.locator('#customer-form-warehouse').click();
    await page.getByRole('option',{name:'Oslo',exact:true}).click();
    await page.getByRole('button',{name:'Save customer',exact:true}).click();
    await page.getByText('This address already belongs to a customer.',{exact:true}).first().waitFor();
    await page.locator('#customer-form-email').fill('browser@example.com');
    await page.getByRole('button',{name:'Save customer',exact:true}).click();
    await page.getByText('Customer saved to SQLite',{exact:true}).waitFor();
  });
  await test('streamed simulator answer and stop',async()=>{
    await go('AI');
    const card=page.locator('#component-AiChat');
    await card.getByRole('textbox').fill('Inspect the orders');
    await card.getByRole('button',{name:'Send message',exact:true}).click();
    await card.getByRole('button',{name:/Stop/}).waitFor();
    await page.waitForTimeout(350);
    await card.getByRole('button',{name:/Stop/}).click();
    assert((await card.innerText()).includes('Inspect the orders'));
    await page.waitForTimeout(400);
    assert.equal(await card.getByRole('button',{name:/Stop/}).count(),0);
  });
  await test('real file upload reaches SQLite',async()=>{
    await go('Files');
    await page.locator('input[type=file]').setInputFiles({name:'browser-upload.txt',mimeType:'text/plain',buffer:Buffer.from('Browser upload bytes')});
    const card=page.locator('#component-UploadQueue');
    const add=card.getByRole('button',{name:'Add files to queue',exact:true});
    if(await add.isVisible()) await add.click();
    await card.getByRole('button',{name:/Start/}).first().click();
    await card.getByText('Completed',{exact:true}).waitFor();
  });
  await test('workflow run starts',async()=>{
    await go('Processes');
    await page.getByRole('button',{name:'Start run',exact:true}).click();
    await page.getByRole('button',{name:'Complete current node',exact:true}).waitFor({state:'visible'});
    assert(!(await page.getByRole('button',{name:'Complete current node',exact:true}).isDisabled()));
  });
  await test('checkbox, radio, slider and quantity input',async()=>{
    await go('Inputs');
    const check=page.locator('#component-Checkbox').getByRole('checkbox');
    await check.focus(); await page.keyboard.press('Space'); assert(await check.isChecked());
    const radio=page.locator('#component-Radio').getByRole('radio',{name:'Express',exact:true});
    await radio.focus();await page.keyboard.press('Space');assert(await radio.isChecked());
    const group=page.locator('#component-CheckboxGroup');
    await group.getByRole('checkbox',{name:'Select all',exact:true}).focus();await page.keyboard.press('Space');
    assert.equal(await group.getByRole('checkbox').evaluateAll(es=>es.filter(e=>e.checked).length),3);
    const slider=page.locator('#component-Slider').getByRole('slider');
    await slider.focus();await page.keyboard.press('ArrowRight');
    assert.equal(await slider.inputValue(),'66');
    const quantity=page.locator('#component-QuantityInput');
    await quantity.getByRole('textbox').fill('12.5');
    await quantity.getByRole('combobox').selectOption({label:'Kilograms (kg)'});
    assert.equal(await quantity.getByRole('textbox').inputValue(),'12.5');
  });
  await test('tag input and inline edit save',async()=>{
    await go('Inputs');
    const tags=page.locator('#component-TagInput');
    await tags.getByRole('textbox').fill('priority');await page.keyboard.press('Enter');
    await tags.getByText('priority',{exact:true}).waitFor();
    assert((await tags.innerText()).includes('priority'));
    const inline=page.locator('#component-InlineEdit');
    await inline.getByRole('button').first().click();
    await inline.getByRole('textbox').fill('Browser warehouse');
    const saved=page.waitForResponse(r=>r.url().endsWith('/api/documents/inline')&&r.request().method()==='PUT');
    await page.keyboard.press('Enter');await saved;
    await inline.getByRole('button').first().waitFor();
    assert((await inline.innerText()).includes('Browser warehouse'));
  });
  await test('multi-select and autocomplete',async()=>{
    await go('Choosing');
    const multi=page.locator('#component-MultiSelect');
    await multi.getByRole('combobox').click();
    await multi.getByRole('option',{name:'Oslo',exact:true}).click();
    await multi.getByRole('option',{name:'Bergen',exact:true}).click();
    await page.keyboard.press('Escape');
    assert((await multi.innerText()).includes('Oslo'));
    assert((await multi.innerText()).includes('Bergen'));
    const auto=page.locator('#component-Autocomplete');
    await auto.getByRole('combobox').fill('Custom destination');
    await page.keyboard.press('Escape');
    assert.equal(await auto.getByRole('combobox').inputValue(),'Custom destination');
  });
  await test('date picker keyboard popup',async()=>{
    await go('Dates');
    const card=page.locator('#component-DatePicker');
    await card.getByRole('textbox').fill('2026-10-25');
    await card.getByRole('textbox').press('Tab');
    assert.equal(await card.getByRole('textbox').inputValue(),'2026-10-25');
    await card.getByRole('button',{name:/calendar/i}).click();
    await card.getByRole('grid').waitFor();
    await page.keyboard.press('Escape');
    await card.getByRole('grid').waitFor({state:'hidden'});
  });
  await test('menu and popover actions',async()=>{
    await go('Actions');
    await page.locator('#component-Menu').getByRole('button').click();
    await page.getByRole('menuitem',{name:'Show message',exact:true}).click();
    await page.getByText('Menu action',{exact:true}).first().waitFor();
    await go('Overlays');
    const popover=page.locator('#component-Popover');
    await popover.getByRole('button',{name:'Open popover',exact:true}).click();
    await popover.getByText('This panel uses Klar positioning.',{exact:true}).waitFor();
    await page.keyboard.press('Escape');
    await popover.getByText('This panel uses Klar positioning.',{exact:true}).waitFor({state:'hidden'});
  });
  await test('drawer and confirm dialog',async()=>{
    await go('Overlays');
    await page.getByRole('button',{name:'Open drawer',exact:true}).click();
    await page.getByRole('dialog',{name:'Order details',exact:true}).waitFor();
    await page.keyboard.press('Escape');
    await page.waitForFunction(()=>document.activeElement.id==='open-drawer');
    await page.getByRole('button',{name:'Confirm a change',exact:true}).click();
    const dialog=page.getByRole('alertdialog',{name:'Confirm action',exact:true});
    await dialog.getByRole('button',{name:/^(Confirm|Delete)$/}).click();
    await dialog.waitFor({state:'hidden'});
    await page.getByText('Event persisted in SQLite',{exact:true}).waitFor();
  });
  await test('tabs accordion and history',async()=>{
    await go('Structure');
    await page.locator('#component-Tabs').getByRole('tab',{name:'History',exact:true}).click();
    await page.getByText('Shipment history',{exact:true}).waitFor();
    await page.locator('#component-Accordion').getByRole('button',{name:'Shipping',exact:true}).click();
    await page.getByText('Delivery in two days.',{exact:true}).waitFor();
    const history=page.locator('#component-History');
    const before=await history.getByRole('textbox').inputValue();
    await history.getByRole('textbox').fill('Edited history note');
    await history.getByRole('button',{name:/Undo/}).click();
    assert.equal(await history.getByRole('textbox').inputValue(),before);
    await history.getByRole('button',{name:/Redo/}).click();
    assert.equal(await history.getByRole('textbox').inputValue(),'Edited history note');
  });
  await test('dirty draft guard stays and leaves',async()=>{
    await go('Structure');
    await page.getByRole('switch',{name:'Mark the sample draft dirty',exact:true}).focus();await page.keyboard.press('Space');
    await page.getByRole('button',{name:'Try leaving the sample draft',exact:true}).click();
    const dialog=page.locator('[role=dialog],[role=alertdialog]');
    await dialog.getByRole('button',{name:/^Stay/}).click();
    await dialog.waitFor({state:'hidden'});
    await page.getByRole('button',{name:'Try leaving the sample draft',exact:true}).click();
    await dialog.getByRole('button',{name:/^Leave/}).click();
    await dialog.waitFor({state:'hidden'});
    await page.getByText('Left the sample draft',{exact:true}).waitFor();
  });
  await test('conflict resolution and discussion persistence',async()=>{
    await go('Collaboration');
    const conflict=page.locator('#component-ConflictResolver');
    await conflict.getByRole('button',{name:'Use all yours',exact:true}).click();
    const saved=page.waitForResponse(r=>r.url().endsWith('/api/documents/merge')&&r.request().method()==='PUT');
    await conflict.getByRole('button',{name:'Apply resolved values',exact:true}).click();await saved;
    const thread=page.locator('#component-CommentThread');
    const comment='Browser discussion '+Date.now();
    await thread.getByRole('textbox').fill(comment);
    await thread.getByRole('button',{name:'Post comment',exact:true}).click();
    await thread.getByText(comment,{exact:true}).waitFor();
    await page.reload();
    await page.locator('#component-CommentThread').getByText(comment,{exact:true}).waitFor();
  });
  await test('AI proposal decision saves',async()=>{
    await go('AI');
    const review=page.locator('#component-AiReview');
    await review.getByRole('radio',{name:'Approve',exact:true}).focus();await page.keyboard.press('Space');
    const saved=page.waitForResponse(r=>r.url().endsWith('/api/documents/review')&&r.request().method()==='PUT');
    await review.getByRole('button',{name:'Save review decisions',exact:true}).click();
    assert((await saved).ok());
  });
  await test('context menu and split button',async()=>{
    await go('Overlays');
    await page.locator('#context-target').click({button:'right'});
    await page.getByRole('menuitem',{name:'Show message',exact:true}).click();
    await page.getByText('Menu action',{exact:true}).first().waitFor();
    await go('Actions');
    await page.locator('#component-SplitButton').getByRole('button').nth(1).click();
    await page.getByRole('menuitem',{name:'Show message',exact:true}).click();
    await page.getByText('Menu action',{exact:true}).first().waitFor();
  });
  await test('retry focuses the stable stat region',async()=>{
    await go('Dashboard');
    await page.getByRole('button',{name:'Clear remote data',exact:true}).click();
    await page.getByRole('button',{name:'Failure / old data',exact:true}).click();
    const region=page.locator('#component-Stat');
    await region.getByRole('button',{name:/Try again/}).click();
    await page.waitForFunction(()=>document.activeElement.id==='orders-stat');
  });
  await test('approval action preserves a focus target',async()=>{
    await go('Access');
    const approval=page.locator('#component-ApprovalFlow');
    await approval.getByRole('button',{name:'Approve',exact:true}).click();
    await page.waitForFunction(()=>document.activeElement.id==='approval');
  });
  await test('tag removal and alert dismissal preserve a focus target',async()=>{
    await go('Feedback');
    await page.locator('#component-Tag').getByRole('button').click();
    await page.waitForFunction(()=>document.activeElement.id==='restore-tag');
    await page.locator('#component-Alert').getByRole('button').click();
    await page.waitForFunction(()=>document.activeElement.id==='restore-alert');
  });
  await test('popup fits near the bottom in a scrolling page at 1024px',async()=>{
    await page.setViewportSize({width:1024,height:600});
    await go('Choosing');
    const trigger=page.locator('#select');
    await trigger.evaluate(el=>el.scrollIntoView({block:'end'}));
    await trigger.focus();await page.keyboard.press('Enter');
    const popup=page.locator('#component-Select').getByRole('listbox');
    await popup.waitFor();
    const box=await popup.boundingBox();
    assert(box && box.y>=0 && box.y+box.height<=601,JSON.stringify(box));
    await page.keyboard.press('Escape');
    await page.waitForFunction(()=>document.activeElement.id==='select');
  });
  await test('all 1024px pages render without page overflow',async()=>{
    await page.setViewportSize({width:1024,height:768});
    for(const group of groups) {await go(group);assert(await page.evaluate(()=>document.documentElement.scrollWidth<=window.innerWidth),'Overflow on '+group);}
  });
  await test('1024px layout renders without page overflow',async()=>{
    await page.setViewportSize({width:1024,height:768});
    await go('Foundations');
    assert(await page.evaluate(()=>document.documentElement.scrollWidth<=window.innerWidth));
    await page.screenshot({path:path.join(screenshots,'1024.png')});
  });
  await browser.close();
  const report={at:new Date().toISOString(),base,results,pageErrors:errors,markupFindings,unexpectedConsoleErrors};
  fs.writeFileSync(path.join(screenshots,'browser-report.json'),JSON.stringify(report,null,2)+'\n');
  const coveragePath=path.join(root,'coverage.json');
  const coverage=JSON.parse(fs.readFileSync(coveragePath));
  const interactions = {
    'Klar.TextInput':'text entry and SQLite snapshot survive reload',
    'Klar.Select':'select keyboard selection and return focus',
    'Klar.Modal':'modal Escape restores opener focus',
    'Klar.Drawer':'drawer and confirm dialog',
    'Klar.ConfirmDialog':'drawer and confirm dialog',
    'Klar.CommandPalette':'command palette shortcut',
    'Klar.Shortcut':'command palette shortcut',
    'Klar.Remote':'remote refresh retains data on failure and can recover',
    'Klar.RemoteView':'remote refresh retains data on failure and can recover',
    'Klar.Stat':'remote refresh retains data on failure and can recover',
    'Klar.Table':'server list search makes a filtered Go request',
    'Klar.ServerList':'server list search makes a filtered Go request',
    'Klar.Form':'form validation then server field rejection',
    'Klar.Form.Submission':'form validation then server field rejection',
    'Klar.Validate':'form validation then server field rejection',
    'Klar.AiChat':'streamed simulator answer and stop',
    'Klar.UploadQueue':'real file upload reaches SQLite',
    'Klar.FileDrop':'real file upload reaches SQLite',
    'Klar.WorkflowRun':'workflow run starts',
    'Klar.Workflow.Engine':'workflow run starts',
    'Klar.Checkbox':'checkbox, radio, slider and quantity input',
    'Klar.CheckboxGroup':'checkbox, radio, slider and quantity input',
    'Klar.Radio':'checkbox, radio, slider and quantity input',
    'Klar.Slider':'checkbox, radio, slider and quantity input',
    'Klar.QuantityInput':'checkbox, radio, slider and quantity input',
    'Klar.TagInput':'tag input and inline edit save',
    'Klar.InlineEdit':'tag input and inline edit save',
    'Klar.MultiSelect':'multi-select and autocomplete',
    'Klar.Autocomplete':'multi-select and autocomplete',
    'Klar.DatePicker':'date picker keyboard popup',
    'Klar.Menu':'menu and popover actions',
    'Klar.Popover':'menu and popover actions',
    'Klar.Tabs':'tabs accordion and history',
    'Klar.Accordion':'tabs accordion and history',
    'Klar.History':'tabs accordion and history',
    'Klar.Switch':'dirty draft guard stays and leaves',
    'Klar.LeaveGuard':'dirty draft guard stays and leaves',
    'Klar.ConflictResolver':'conflict resolution and discussion persistence',
    'Klar.CommentThread':'conflict resolution and discussion persistence',
    'Klar.AiReview':'AI proposal decision saves',
    'Klar.ContextMenu':'context menu and split button',
    'Klar.SplitButton':'context menu and split button',
    'Klar.Tag':'tag removal and alert dismissal preserve a focus target',
    'Klar.Alert':'tag removal and alert dismissal preserve a focus target'
  };
  const allRendersPassed=groups.every(group=>results.some(r=>r.name==='render '+group&&r.passed));
  for(const entry of coverage){entry.browserRenderVerified=allRendersPassed;entry.interactionVerified=results.some(r=>r.name===interactions[entry.module]&&r.passed);}
  fs.writeFileSync(coveragePath,JSON.stringify(coverage,null,2)+'\n');
  if(results.some(r=>!r.passed)||errors.length||unexpectedConsoleErrors.length) process.exitCode=1;
})().catch(error=>{console.error(error);process.exitCode=1});
